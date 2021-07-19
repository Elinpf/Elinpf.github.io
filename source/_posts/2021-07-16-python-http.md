---
title: python http
date: 2021-07-16 10:05:39
tags:
- http
- server
categories:
- 编程
- python
---

## HTTP Server

参考一个完整的服务端配置

```python server.py
#!/usr/bin/env python3
"""
Very simple HTTP server in python for logging requests
Usage::
    ./server.py [<port>]
"""
from http.server import BaseHTTPRequestHandler, HTTPServer
import logging

token = open("token").read().strip()

class S(BaseHTTPRequestHandler):
    def _set_response(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()

    def do_GET(self):
        logging.info("GET request,\nPath: %s\nHeaders:\n%s\n", str(self.path), str(self.headers))
        self._set_response()
        self.wfile.write("GET request for {}".format(self.path).encode('utf-8'))

    def do_POST(self):
        content_length = int(self.headers['Content-Length']) # <--- Gets the size of data
        post_data = self.rfile.read(content_length) # <--- Gets the data itself
        logging.info("POST request, Body:\n%s\n", post_data.decode('utf-8'))

        self._set_response()

        if (post_data.decode('utf-8') == f"token={token}"):
            logging.info("[+] Token Success\n")
            self.wfile.write("Token Success".encode('utf-8'))
        else:
            logging.info("[-] Token Failed\n")
            self.wfile.write("Token Failed".encode('utf-8'))



def run(server_class=HTTPServer, handler_class=S, port=8080):
    logging.basicConfig(level=logging.INFO)
    server_address = ('', port)
    httpd = server_class(server_address, handler_class)
    logging.info('Starting httpd...\n')
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()
    logging.info('Stopping httpd...\n')

if __name__ == '__main__':
    from sys import argv

    if len(argv) == 2:
        run(port=int(argv[1]))
    else:
        run()
```

## http Client

POST 方法参考

```python
from urllib3 import PoolManager
from urllib.parse import urlencode, urljoin
import chardet

def get_chapters()
    # highlight-next-line
    http = PoolManager()

    post_url = 'https://info.support.huawei.com/network/ptmngsys/getTsrevList'
    data = {
        'lang': 'CN',
        'family': family_str
    }
    # highlight-start
    res = http.request('POST', post_url, body=urlencode(data),
                       headers={
                           'Cookie': 'JSESSIONID=F5D938CEFxxxxxxxxxxxxx4559465B96; infosupport_network_ptmngsys_sticky=pro_dggpmw1tmc02615.huawei.com_8080:3; hwsso_uniportal=""; hwsso_login=""',
                           'Host': 'info.support.huawei.com',
                           'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8'
    }
    )
    # highlight-end
    if res.status != 200:
        print("Can't open web, check cookie value.")
        return

    encode_type = chardet.detect(res.data)  # 自动判断编码类型
    body = res.data.decode(encode_type['encoding'])
```