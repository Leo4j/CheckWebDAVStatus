# CheckWebDAVStatus

Checks for WebDAV Service Status Enabled on all hosts in the network

Run as follows:

```
iex(new-object net.webclient).downloadstring('https://raw.githubusercontent.com/Leo4j/CheckWebDAVStatus/main/CheckWebDAVStatus.ps1')
```
```
CheckWebDAVStatus
```
```
CheckWebDAVStatus -threads 100
```

Powershell implementation of `GetWebDAVStatus`: https://github.com/g0ldengunsec/getwebdavstatus
