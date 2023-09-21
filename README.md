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

Check for active Sessions on all hosts having WebDAV Service Status Enabled - uses [Invoke-SessionHunter](https://github.com/Leo4j/Invoke-SessionHunter)

```
CheckWebDAVStatus -Sessions
```

Check all hosts in the target domain for WebDAV Service Status Enabled

```
CheckWebDAVStatus -Domain domain.local
```

Check for WebDAV Service Status Enabled on specified targets (specify the domain name to target a different domain)

```
CheckWebDAVStatus -Targets "Host1,Host2"
```
```
CheckWebDAVStatus -Targets "Host1.domain.local,Host2.contoso.local"
```

Check for WebDAV Service Status Enabled on a list of targets (one per line)

```
CheckWebDAVStatus -TargetsFile c:\Users\Public\Documents\target_hosts.txt
```

Set a custom Output path
```
CheckWebDAVStatus -OutputPath c:\Users\Public\Documents\WebDAVStatusEnabled.txt
```
