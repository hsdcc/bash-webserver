#!/usr/bin/env bash

PORT=8000
FILES_DIR="$(pwd)/files"
mkdir -p "$FILES_DIR"

echo "server started on port $PORT, saving files to $FILES_DIR"

while true; do
  # -k 1 means close after 1 sec of inactivity, adjust if needed
  nc -l -p "$PORT" -q 1 | (
    # read request line
    read -r request_line
    headers=()
    # read headers until empty line
    while IFS= read -r line && [[ "$line" != $'\r' && -n "$line" ]]; do
      headers+=("$line")
    done

    method=$(echo "$request_line" | cut -d' ' -f1)
    path=$(echo "$request_line" | cut -d' ' -f2)

    if [[ "$method" == "GET" && ( "$path" == "/" || "$path" == "/index.html" ) ]]; then
      cat <<EOF
HTTP/1.1 200 OK
Content-Type: text/plain
Content-Length: 4

test
EOF
      exit 0
    fi

    if [[ "$method" == "POST" && "$path" == "/upload" ]]; then
      content_length=0
      content_type=""
      for h in "${headers[@]}"; do
        if [[ "$h" =~ ^Content-Length:[[:space:]]*([0-9]+) ]]; then
          content_length="${BASH_REMATCH[1]}"
        fi
        if [[ "$h" =~ ^Content-Type:[[:space:]]*(.*) ]]; then
          content_type="${BASH_REMATCH[1]}"
        fi
      done

      if [[ "$content_length" -le 0 ]]; then
        echo -e "HTTP/1.1 411 Length Required\r"
        echo -e "Content-Type: text/plain\r"
        echo -e "Content-Length: 15\r"
        echo -e "\r"
        echo "Length Required"
        exit 0
      fi

      if ! [[ "$content_type" =~ boundary=([^;]+) ]]; then
        echo -e "HTTP/1.1 400 Bad Request\r"
        echo -e "Content-Type: text/plain\r"
        echo -e "Content-Length: 12\r"
        echo -e "\r"
        echo "No boundary"
        exit 0
      fi
      boundary="${BASH_REMATCH[1]}"

      # read the full body (exact bytes)
      read -r -N "$content_length" raw_body

      tmpfile=$(mktemp)
      echo "$raw_body" > "$tmpfile"

      # extract filename from multipart data
      filename=$(awk -v RS="--$boundary" '
        /Content-Disposition/ {
          if(match($0, /filename="([^"]+)"/, arr)) {
            print arr[1]
            exit
          }
        }' "$tmpfile")

      if [[ -z "$filename" ]]; then
        echo -e "HTTP/1.1 400 Bad Request\r"
        echo -e "Content-Type: text/plain\r"
        echo -e "Content-Length: 20\r"
        echo -e "\r"
        echo "No filename found"
        rm -f "$tmpfile"
        exit 0
      fi

      # generate a unique filename if file exists: test.txt → test(2).txt etc
      base="${filename%.*}"
      ext="${filename##*.}"
      target="$FILES_DIR/$filename"
      i=2
      while [[ -e "$target" ]]; do
        target="$FILES_DIR/${base}($i).${ext}"
        ((i++))
      done

      # extract file content from multipart body and save to target
      awk -v RS="--$boundary" -v target="$target" '
      /Content-Disposition/ {
        split($0, parts, "\r\n\r\n")
        if (length(parts) > 1) {
          data = parts[2]
          sub(/\r\n--$/, "", data)
          print data > target
        }
      }' "$tmpfile"

      rm -f "$tmpfile"

      msg="Done! saved to $(basename "$target")"
      len=${#msg}

      echo -e "HTTP/1.1 201 Created\r"
      echo -e "Content-Type: text/plain\r"
      echo -e "Content-Length: $len\r"
      echo -e "\r"
      echo "$msg"

      exit 0
    fi

    # fallback 404
    echo -e "HTTP/1.1 404 Not Found\r"
    echo -e "Content-Type: text/plain\r"
    echo -e "Content-Length: 9\r"
    echo -e "\r"
    echo "Not Found"
  )
done
