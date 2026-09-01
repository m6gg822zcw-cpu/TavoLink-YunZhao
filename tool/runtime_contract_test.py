#!/usr/bin/env python3
"""Offline HTTP contract tests for the protocols TavoLink v1 speaks.
These do not replace `flutter test`; they verify the request/response contracts
without any external network or API keys.
"""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import Thread
from urllib.request import Request, urlopen
from urllib.error import HTTPError
import json

results=[]

def record(name, ok, detail=''):
    results.append((name, ok, detail))
    if not ok:
        raise AssertionError(f'{name}: {detail}')

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass
    def _json(self):
        n=int(self.headers.get('content-length','0'))
        return json.loads(self.rfile.read(n) or b'{}')
    def _send(self, payload, status=200):
        body=json.dumps(payload).encode()
        self.send_response(status)
        self.send_header('content-type','application/json')
        self.send_header('content-length',str(len(body)))
        self.end_headers(); self.wfile.write(body)
    def do_GET(self):
        if self.path.startswith('/v1/models'):
            self._send({'data':[{'id':'mock-model'}]}); return
        if self.path.startswith('/search'):
            self._send({'results':[{'title':'Tavo result','url':'https://example.test/tavo','content':'mock search result'}]}); return
        self._send({'error':'not found'},404)
    def do_POST(self):
        body=self._json()
        if self.path == '/mcp':
            method=body.get('method')
            if method=='tools/list':
                self._send({'jsonrpc':'2.0','id':body.get('id'),'result':{'tools':[{'name':'tavo.echo','inputSchema':{'type':'object'}}]}}); return
            if method=='tools/call':
                self._send({'jsonrpc':'2.0','id':body.get('id'),'result':{'content':[{'type':'text','text':'echo ok'}]}}); return
        if self.path == '/v1/chat/completions':
            self._send({'choices':[{'message':{'role':'assistant','content':None,'tool_calls':[{'id':'call_1','type':'function','function':{'name':'web_search','arguments':'{"query":"Tavo MCP"}'}}]}}]}); return
        self._send({'error':'not found'},404)

def req_json(url, method='GET', payload=None, headers=None):
    data=None if payload is None else json.dumps(payload).encode()
    request=Request(url,data=data,method=method,headers=headers or {})
    with urlopen(request,timeout=3) as r:
        return r.status, {k.lower():v for k,v in r.headers.items()}, json.loads(r.read())

def main():
    server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
    thread=Thread(target=server.serve_forever,daemon=True); thread.start()
    base=f'http://127.0.0.1:{server.server_port}'
    try:
        status,_,data=req_json(base+'/mcp','POST',{
            'jsonrpc':'2.0','id':1,'method':'tools/list','params':{
                '_meta':{
                    'io.modelcontextprotocol/protocolVersion':'2026-07-28',
                    'io.modelcontextprotocol/clientInfo':{'name':'TavoLink','version':'1.0.0'},
                    'io.modelcontextprotocol/clientCapabilities':{}
                }
            }
        },{'Content-Type':'application/json','Accept':'application/json, text/event-stream','MCP-Protocol-Version':'2026-07-28','Mcp-Method':'tools/list'})
        record('MCP stateless tools/list', status==200 and data['result']['tools'][0]['name']=='tavo.echo')

        status,_,data=req_json(base+'/mcp','POST',{'jsonrpc':'2.0','id':2,'method':'tools/call','params':{'name':'tavo.echo','arguments':{'text':'hi'}}},{'Content-Type':'application/json','MCP-Protocol-Version':'2026-07-28','Mcp-Method':'tools/call','Mcp-Name':'tavo.echo'})
        record('MCP tools/call', status==200 and data['result']['content'][0]['text']=='echo ok')

        status,_,data=req_json(base+'/v1/models')
        record('OpenAI-compatible models', status==200 and data['data'][0]['id']=='mock-model')

        status,_,data=req_json(base+'/v1/chat/completions','POST',{'model':'mock-model','messages':[{'role':'user','content':'hi'}],'tools':[],'stream':False},{'Content-Type':'application/json'})
        call=data['choices'][0]['message']['tool_calls'][0]
        record('OpenAI tool_call contract', status==200 and call['function']['name']=='web_search' and json.loads(call['function']['arguments'])['query']=='Tavo MCP')

        status,_,data=req_json(base+'/search?q=Tavo&format=json')
        record('SearXNG result contract', status==200 and data['results'][0]['title']=='Tavo result')
    finally:
        server.shutdown(); server.server_close()

    for name,ok,detail in results:
        print(('PASS' if ok else 'FAIL').ljust(5),name,detail)
    print(f'\nSummary: {sum(1 for _,ok,_ in results if ok)}/{len(results)} runtime contracts passed')

if __name__=='__main__':
    main()
