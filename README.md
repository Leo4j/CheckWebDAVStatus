# CheckWebDAVStatus

Checks for WebDAV Service Status Enabled on all hosts in the network, or specific targets only

Run as follows:

```
iex(new-object net.webclient).downloadstring('https://raw.githubusercontent.com/Leo4j/CheckWebDAVStatus/main/CheckWebDAVStatus.ps1')
```

Check all hosts in the current domain for WebDAV Service Status Enabled

```
CheckWebDAVStatus
```

Check all hosts in the target domain for WebDAV Service Status Enabled

```
CheckWebDAVStatus -Domain domain.local
```

Check for WebDAV Service Status Enabled on specified targets (current domain)

```
CheckWebDAVStatus -Targets "Host1,Host2"
```

Check for WebDAV Service Status Enabled on specified targets

```
CheckWebDAVStatus -Targets "Host1.domain.local,Host2.contoso.local"
```

Bump up Threads (default: 20)

```
CheckWebDAVStatus -Threads 100
```

Set a custom Output path
```
CheckWebDAVStatus -OutputPath c:\Users\Public\Documents\SMBSigningNotRequired.txt
```

Powershell implementation of `GetWebDAVStatus`: https://github.com/g0ldengunsec/getwebdavstatus
