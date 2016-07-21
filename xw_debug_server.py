#!/usr/bin/env python
# encoding: utf-8

import sys
import os
import socket
import select
import json
import signal
import struct
import time
import threading
import base64

style = {
    0 : 31, # red
    1 : 32, # green
    2 : 36, # cyan
    3 : 37, # white
}

def get_ip():
    flag = False
    for line in os.popen("/sbin/ifconfig"):
        if line.find('en0:') > -1:
            flag = True
        if flag == True and line.find('broadcast') > -1:
            arr = line.split(' ')
            return arr[1]
    return ''

class LogServer(object):
    def __init__(self):
        self.timeout = 10 * 60
        self.file_lock = threading.Lock();
        self.host = get_ip()
        self.port = 9999
        print 'LogServer have started, you can connect to the following address:(ip=%s, port=%d)' % (self.host, self.port)
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
        self.sock.bind((self.host, self.port))
        signal.signal(signal.SIGINT, self.sighandler)

    def sighandler(self, *args):
        print '\033[%d;40m%s' % (style[3], 'log_server is shutting down...')
        self.sock.close()

    def write_file(self, path, base64_data, status):
        with self.file_lock:
            data = base64.b64decode(base64_data)
            mode = None
            if status == 1:
                mode = 'w+b'
            else:
                mode = 'a'
            f = open(path, mode)
            f.write(data)
            f.close()
            if status == 2:
                print '\033[%d;40m%s %s' % (style[2], os.path.basename(path), 'upload success!')
                print '\033[%d;40m%s' % (style[3], '')

    def deal_data(self, data):
        json_data = json.loads(data)
        event_type = json_data["type"]
        if event_type == 'upload':
            path = json_data["path"]
            base_path = os.path.expanduser("~")
            path = base_path + '/Desktop/' + path
            base64_data = json_data["data"]
            status = json_data["status"]
            t = threading.Thread(target=self.write_file, args=(path, base64_data, status,))
            t.start()
        else:
            level = json_data["level"]
            content = json_data["content"]
            print '\033[%d;40m%s' % (style[level], content)
            print '\033[%d;40m%s' % (style[3], '')

    def run(self):
        self.sock.listen(5)
        self.sock.setblocking(0)
        self.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.kq = select.kqueue()
        kevents = [select.kevent(self.sock.fileno(), filter=select.KQ_FILTER_READ, flags=select.KQ_EV_ADD|select.KQ_EV_ENABLE|select.KQ_EV_EOF)]
        try:
            connections = {}
            recvs = {}
            timeouts = {}
            while True:
                events = self.kq.control(kevents, 1, self.timeout)
                cur_time = int(time.time())
                for t in timeouts.keys():
                    if cur_time - timeouts[t] >= self.timeout:
                        kevents.remove(select.kevent(connections[t].fileno(), select.KQ_FILTER_READ, select.KQ_EV_ADD|select.KQ_EV_EOF, udata=t))
                        connections[t].close()
                        if t in connections:
                            del connections[t]
                        if t in recvs:
                            del recvs[t]
                        del timeouts[t]
                for event in events:
                    if event.ident == self.sock.fileno():
                        connection, address = self.sock.accept()
                        print '\033[%d;40m%s%s' % (style[3], "connect from ", address)
                        print '\033[%d;40m%s' % (style[3], '')
                        connection.setblocking(0)
                        connections[connection.fileno()] = connection
                        kevents.append(select.kevent(connection.fileno(), filter=select.KQ_FILTER_READ, flags=select.KQ_EV_ADD|select.KQ_EV_EOF, udata=connection.fileno()))
                    elif event.udata in connections:
                        if event.flags & select.KQ_EV_EOF:
                            kevents.remove(select.kevent(connections[event.udata].fileno(), select.KQ_FILTER_READ, select.KQ_EV_ADD|select.KQ_EV_EOF, udata=event.udata))
                            if event.udata in connections:
                                del connections[event.udata]
                            if event.udata in recvs:
                                del recvs[event.udata]
                            if event.udata in timeouts:
                                del timeouts[event.udata]
                            continue
                        timeouts[event.udata] = int(time.time())
                        data = connections[event.udata].recv(1024)
                        if event.udata in recvs:
                            recvs[event.udata] += data
                        else:
                            recvs[event.udata] = data
                        while len(recvs[event.udata]) >= 4:
                            body_len = struct.unpack("<i", recvs[event.udata][0:4])[0]
                            if body_len + 4 > len(recvs[event.udata]):
                                break
                            body_data = recvs[event.udata][4:body_len+4]
                            self.deal_data(body_data)
                            remain_data = recvs[event.udata][4+body_len:]
                            recvs[event.udata] = remain_data
                            send_body_dict = {"response":{"code":0,"msg":"success"}}
                            send_body_json = json.dumps(send_body_dict, ensure_ascii=False)
                            send_body_len = len(send_body_json)
                            send_data = struct.pack("<i", send_body_len)
                            send_data += send_body_json
                            connections[event.udata].send(send_data)
        finally:
            self.kq.close()
            self.sock.close()

if __name__ == '__main__':
    server = LogServer()
    server.run()

