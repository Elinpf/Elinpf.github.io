---
title: Ceph RGW 跨域（CORS）问题处理
date: 2026-01-13 10:43:47
tags:
- ceph
- rgw
- cors
categories:
- 运维
- Ceph
---

### 验证CORS配置

首先确认cors 配置是否为空，是以桶为单位的，使用s3cmd 比 aws好用

```Bash
root@ceph-1:~/ceph_config# s3cmd --host=10.0.0.241:32002 --no-ssl info s3://test-lifecycle-1day
s3://test-lifecycle-1day/ (bucket):
   Location:  s3-dev-pool
   Payer:     BucketOwner
   Ownership: none
   Versioning:none
   Expiration Rule: all objects in this bucket will expire in '3' day(s) after creation
   Block Public Access: none
   Policy:    none
   CORS:      none  <----  这里
   ACL:       cosi: FULL_CONTROL

# 或者
root@ceph-1:~/ceph_config# aws --endpoint-url http://10.0.0.241:32002 --no-verify-ssl s3api get-bucket-cors --bucket test-lifecycle-1day

argument of type 'NoneType' is not iterable
```

### 解决办法

```Bash
# 1. 创建CORS规则文件
cat > cors.json <<EOF
{
  "CORSRules": [
    {
      "AllowedOrigins": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
      "AllowedHeaders": ["*"],
      "MaxAgeSeconds": 3000
    }
  ]
}
EOF

# 2. 直接设置（覆盖原有配置）
aws --endpoint-url http://10.0.0.241:32002 \
  --no-verify-ssl \
  s3api put-bucket-cors \
  --bucket test-lifecycle-1day \
  --cors-configuration file://cors.json

# 3. 验证（设置后应能正常读取）
aws --endpoint-url http://10.0.0.241:32002 \
  --no-verify-ssl \
  s3api get-bucket-cors \
  --bucket test-lifecycle-1day
```

### 实际环境配置

```Bash
# 跨域配置
cat > cors.json <<EOF
{
  "CORSRules": [
    {
      "AllowedOrigins": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
      "AllowedHeaders": ["*"],
      "MaxAgeSeconds": 3000
    }
  ]
}
EOF

# 设置
aws --endpoint-url https://s3-dev-pool.cnzbai.com  \
  s3api put-bucket-cors \
  --bucket cors-test-bucket \
  --cors-configuration file://cors.json

# 验证
aws --endpoint-url https://s3-dev-pool.cnzbai.com \
  s3api get-bucket-cors \
  --bucket cors-test-bucket
```

#### 通过 S3 Brower配置

```XML
<CORSConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <CORSRule>
    <AllowedMethod>GET</AllowedMethod>
    <AllowedMethod>PUT</AllowedMethod>
    <AllowedMethod>DELETE</AllowedMethod>
    <AllowedMethod>HEAD</AllowedMethod>
    <AllowedMethod>POST</AllowedMethod>
    <AllowedOrigin>*</AllowedOrigin>
    <AllowedHeader>*</AllowedHeader>
    <MaxAgeSeconds>3000</MaxAgeSeconds>
  </CORSRule>
</CORSConfiguration>
```
