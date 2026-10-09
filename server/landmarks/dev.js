'use strict';
const http = require('node:http');
const { handle } = require('./catalog');
const port = Number(process.env.LANDMARK_PORT || 4319);
if (!Number.isInteger(port) || port < 1024 || port > 65535) throw new Error('invalid_preview_port');
const server = http.createServer(async (req,res) => {
  let body='';let bytes=0;
  try {
    for await(const chunk of req){bytes+=chunk.byteLength;if(bytes>1024){res.writeHead(413);res.end();return;}body+=chunk.toString('utf8');}
    const url=new URL(req.url,`http://127.0.0.1:${port}`);
    const result=url.pathname === '/api/landmarks' ? handle({method:req.method,body,query:url.search,enabled:true}) : {status:404,headers:{},body:'{}'};
    res.writeHead(result.status,result.headers);res.end(result.body);
  } catch {res.writeHead(400);res.end('{}');}
});
server.requestTimeout=5000;server.headersTimeout=3000;
server.listen(port,'127.0.0.1',()=>console.log(`Fonsters offline landmark preview: http://127.0.0.1:${port}/api/landmarks`));
for(const signal of ['SIGINT','SIGTERM'])process.on(signal,()=>server.close());
