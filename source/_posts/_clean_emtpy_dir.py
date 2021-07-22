import os

# 遍历目录下的所有文件夹，并删除空文件夹
path = '.'

for root, dirs, files in os.walk(path):
    for dir in dirs:
        if not os.listdir(dir):
            print('移除空文件夹:', dir)
            os.rmdir(dir)
