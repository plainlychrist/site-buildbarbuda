Setting a new default bootstrap
---

Set `BURL` to the URL of the website which you want to make the default for bootstrapping. Then follow the commands:

```bash
BURL=http://localhost/sites/default/files/public-backups/
curl -s -o latest.txt $BURL/latest.txt && LTT=$(< latest.txt) && curl -s -o $LTT.plain-dump.sql.txt $BURL/$LTT.plain-dump.sql.txt && curl -s -o $LTT.sanitized-dump.sql.txt $BURL/$LTT.sanitized-dump.sql.txt && curl -s -o $LTT.sanitized-restore.sql.txt $BURL/$LTT.sanitized-restore.sql.txt
```
