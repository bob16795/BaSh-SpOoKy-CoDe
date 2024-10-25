#!/bin/bash

## Create the response FIFO
rm -f response
mkfifo response

function handle_GET() {
  HEAD=$(cat header.html)
  FOOT=$(cat footer.html)
  RESULT=$(${REQUEST:5})
  RESPONSE=$(echo "$HEAD$RESULT$FOOT")
}

function handle_GET_home() {
  HEAD=$(cat header.html)
  RESPONSE=$(echo "$HEAD")
}

## most of the rest of the code is slightly modified from a random gh gist (closed it so no link, you can problaby find it though)

function handleRequest() {
  ## Read the HTTP request until \r\n
  while read line; do
    echo $line
    trline=$(echo $line | tr -d '[\r\n]') ## Removes the \r\n from the EOL

    ## Breaks the loop when line is empty
    [ -z "$trline" ] && break

    ## Parses the headline
    ## e.g GET /login HTTP/1.1 -> GET /login
    HEADLINE_REGEX='(.*?)\s(.*?)\sHTTP.*?'
    [[ "$trline" =~ $HEADLINE_REGEX ]] &&
      REQUEST=$(echo $trline | sed -E "s/$HEADLINE_REGEX/\1 \2/")

    ## Parses the Content-Length header
    ## e.g Content-Length: 42 -> 42
    CONTENT_LENGTH_REGEX='Content-Length:\s(.*?)'
    [[ "$trline" =~ $CONTENT_LENGTH_REGEX ]] &&
      CONTENT_LENGTH=$(echo $trline | sed -E "s/$CONTENT_LENGTH_REGEX/\1/")

    ## Parses the Cookie header
    ## e.g Cookie: name=John -> name John
    COOKIE_REGEX='Cookie:\s(.*?)\=(.*?).*?'
    [[ "$trline" =~ $COOKIE_REGEX ]] &&
      read COOKIE_NAME COOKIE_VALUE <<< $(echo $trline | sed -E "s/$COOKIE_REGEX/\1 \2/")
  done

  ## Read the remaining HTTP request body
  if [ ! -z "$CONTENT_LENGTH" ]; then
    BODY_REGEX='(.*?)=(.*?)'

    while read -n$CONTENT_LENGTH -t1 line; do
      echo $line
      trline=`echo $line | tr -d '[\r\n]'`

      [ -z "$trline" ] && break

      read INPUT_NAME INPUT_VALUE <<< $(echo $trline | sed -E "s/$BODY_REGEX/\1 \2/")
    done
  fi

  ## Route request to the response handler
  case "$REQUEST" in
    "GET /") handle_GET_home;;
    *) handle_GET;;
  esac

  echo -e "$RESPONSE" > response
}

echo 'Listening on 2280...'

## Keep the server running forever
while true; do
  ## 1. wait for FIFO
  ## 2. creates a socket and listens to the port 3000
  ## 3. as soon as a request message arrives to the socket, pipes it to the handleRequest function
  ## 4. the handleRequest function processes the request message and routes it to the response handler, which writes to the FIFO
  ## 5. as soon as the FIFO receives a message, it's sent to the socket
  ## 6. closes the connection (`-N`), closes the socket and repeat the loop
  cat response | nc -lN 2280 | handleRequest
done