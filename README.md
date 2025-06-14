# minimal bash + netcat file server

a minimal **bash + netcat** webserver for uploading and downloading files in a single script.

## features

* 🚀 runs on port **8000**
* 📁 stores uploads in a `files/` folder created alongside the script
* 🔁 avoids name collisions: `file.txt` → `file(2).txt`, `file(3).txt`, etc.
* 🔍 terminal logs every request: `request: METHOD PATH`

## endpoints

| method | path                 | action                                  |
| ------ | -------------------- | --------------------------------------- |
| GET    | `/` or `/index.html` | returns plain text `test`               |
| POST   | `/upload`            | accepts multipart form-data, saves file |
| GET    | `/filename`          | serves/downloads that file if it exists |
| \*     | any other            | responds `404 Not Found`                |

## setup & run

1. save the script below as `webserver.sh` in your working directory
2. make it executable:

   ```bash
   chmod +x webserver.sh
   ```
3. start the server:

   ```bash
   ./webserver.sh
   ```

   * listens on `0.0.0.0:8000`
   * creates `files/` if missing

> to background the server:
>
> ```bash
> nohup ./webserver.sh &> server.log &
> ```

## example usage

* upload a file:

  ```bash
  curl -F "file=@test.txt" http://<ip>:8000/upload
  ```

  returns `Done! saved to test.txt` (or `test(2).txt` if name exists)

* download a file:

  ```bash
  curl http://<ip>:8000/test.txt -o downloaded.txt
  ```

* test endpoint:

  ```bash
  curl http://<ip>:8000/
  # prints "test"
  ```

## customizing

* change the listening port: edit the `PORT=8000` variable at the top of `webserver.sh`
* change storage location: edit the `FILES_DIR` definition

---

### the script (`webserver.sh`)

```bash
$(sed -n '1,200p' webserver.sh)
```
