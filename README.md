# CheckWebDAVStatus

Checks for WebDAV Service Status Enabled on all hosts in the network, or specific targets only

Run as follows:

```
iex(new-object net.webclient).downloadstring('https://raw.githubusercontent.com/Leo4j/CheckWebDAVStatus/main/CheckWebDAVStatus.ps1')
```

Check for WebDAV Service Status Enabled on all hosts in the network

```
CheckWebDAVStatus
```

Check for WebDAV Service Status Enabled on specified targets

```
CheckWebDAVStatus -Targets "Host1,Host2"
```

Bump up Threads (default: 20)

```
CheckWebDAVStatus -Threads 100
```

Powershell implementation of `GetWebDAVStatus`: https://github.com/g0ldengunsec/getwebdavstatus
