# CheckWebDAVStatus

Checks for WebDAV Service Status Enabled on all hosts in the network, or specific targets only

Run as follows:

```
iex(new-object net.webclient).downloadstring('https://raw.githubusercontent.com/Leo4j/CheckWebDAVStatus/main/CheckWebDAVStatus.ps1')
```
```
CheckWebDAVStatus # Checks WebDAV Service Status Enabled on all hosts in the network
```
```
CheckWebDAVStatus -Targets "Host1,Host2" # Checks WebDAV Service Status Enabled on specified targets
```
```
CheckWebDAVStatus -Threads 100
```

Powershell implementation of `GetWebDAVStatus`: https://github.com/g0ldengunsec/getwebdavstatus
