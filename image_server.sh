#!/bin/bash
#UNMENU_RELEASE $Revision$ $Date$
# a minimal image web-server highly reliant on inetd.
base=/var
read request

while /bin/true; do
  read header
  [ "$header" == $'\r' ] && break;
done

url="${request#GET }"
url="${url% HTTP/*}"

case "$url" in
*\.\./*)
  echo -e "HTTP/1.1 403 Forbidden\r"
  echo -e "Content-Type: text/html\r"
  echo -e "\r"
  echo -e "403 Permission Denied\r"
  echo -e "\r"
  exit
;;
*.jpg) ctype="image/jpeg" ;;
*.png) ctype="image/png" ;;
*.gif) ctype="image/gif" ;;
*)
  echo -e "HTTP/1.1 403 Forbidden\r"
  echo -e "Content-Type: text/html\r"
  echo -e "\r"
  echo -e "403 Permission denied\r"
  echo -e "\r"
  exit
;;
esac

filename="$base$url"
if [ -f "$filename" ]; then
  echo -e "HTTP/1.1 200 OK\r"
  echo -e "Content-Type: $ctype\r"
  echo -e "\r"
  cat "$filename"
  echo -e "\r"
else
  echo -e "HTTP/1.1 404 Not Found\r"
  echo -e "Content-Type: text/html\r"
  echo -e "\r"
  echo -e "404 Not Found\r"
  echo -e "<br>$filename Not Found\r"
  echo -e "\r"
fi

