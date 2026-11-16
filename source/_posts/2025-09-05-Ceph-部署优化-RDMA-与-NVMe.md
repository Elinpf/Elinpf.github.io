---
title: Ceph 部署优化：RDMA 与 NVMe
date: 2025-09-05 09:33:00
tags:
- ceph
- rdma
categories:
- 运维
- Ceph
---

- [kubernetes应用-rook ceph集群内部署 - 可乐去冰](https://isekiro.com/kubernetes%E5%BA%94%E7%94%A8-rook-ceph%E9%9B%86%E7%BE%A4%E5%86%85%E9%83%A8%E7%BD%B2/)
- [https://rook.io/docs/rook/latest-release/Storage-Configuration/Object-Storage-RGW/object-storage/](https://rook.io/docs/rook/latest-release/Storage-Configuration/Object-Storage-RGW/object-storage/)
- [[ceph 的通用解决方案] - 3.如何将 ssd 作为 hdd 的缓存池_ceph使用ssd配置读写缓存-CSDN博客](https://blog.csdn.net/li4528503/article/details/106256536)
- [https://docs.redhat.com/zh-cn/documentation/red_hat_ceph_storage/4/html/storage_strategies_guide/pg_count](https://docs.redhat.com/zh-cn/documentation/red_hat_ceph_storage/4/html/storage_strategies_guide/pg_count)

[pgcalc PG计算器](https://docs.ceph.com/en/squid/rados/operations/pgcalc/)

- [DeepSeek](https://chat.deepseek.com/share/rpv1wvsdxqki65613j)
- [https://docs.ceph.com/en/latest/rados/configuration/network-config-ref/](https://docs.ceph.com/en/latest/rados/configuration/network-config-ref/)
## RDMA优化

```Markdown
# 设置全局RDMA配置
ceph config set global ms_type async+rdma
ceph config set global ms_async_rdma_type ib
ceph config set global ms_async_rdma_device_name ibp129s0
ceph config set global ms_async_rdma_port_num 1

# 为OSD、MON、MGR分别设置
ceph config set osd ms_type async+rdma
ceph config set osd ms_async_rdma_type ib  
ceph config set osd ms_async_rdma_device_name ibp129s0
ceph config set osd ms_async_rdma_port_num 1

ceph config set mon ms_type async+rdma
ceph config set mgr ms_type async+rdma
```

## NVMe优化

```Markdown
# 优化OSD配置以适应NVMe性能
ceph config set osd bluestore_cache_autotune true
ceph config set osd bluestore_cache_size_hdd 0
ceph config set osd bluestore_cache_size_ssd 4294967296  # 4GB缓存
ceph config set osd osd_op_num_threads_per_shard 4
ceph config set osd osd_op_num_shards 8

# 增加网络并发
ceph config set osd ms_async_op_threads 16
```
