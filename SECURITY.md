# Security

RackPal is a desktop application that works on local files. It makes no network connections of its
own, sends no telemetry and has no accounts. The attack surface that matters is **opening a project
or template file someone else gave you**: the file readers, and the PDF renderer behind the preview.

## Reporting a problem

Please **do not open a public issue** for a security problem. Email
**rileytherackpal@proton.me** with:

- the RackPal version (`Help` ▸ `About RackPal…`),
- what an attacker could do, and
- a file or steps that show it, if you have one.

This is a one-person alpha, so there is no response-time promise, but a report will be read and
answered.

## Supported versions

Only the newest preview release is supported. There are no backports during the alpha.
