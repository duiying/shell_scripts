#!/bin/bash

set -e

FABIO_VERSION="1.5.8"
FABIO_DONWLOAD_URL="https://github.com/fabiolb/fabio/releases/download/v${FABIO_VERSION}/fabio-${FABIO_VERSION}-go1.10-linux_amd64"

preinstall(){
    getent group fabio >/dev/null || groupadd -r fabio
    getent passwd fabio >/dev/null || useradd -r -g fabio -d /var/lib/fabio -s /sbin/nologin -c "fabio user" fabio
}

postinstall(){
    # Initial installation
    systemctl --no-reload preset fabio.service >/dev/null 2>&1 || :
    systemctl enable fabio
    if [ ! -d /etc/fabio ]; then
        mkdir /etc/fabio
    fi
}

preuninstall(){
    # Package removal, not upgrade
    systemctl --no-reload disable --now fabio.service > /dev/null 2>&1 || :
}

install(){
    wget ${FABIO_DONWLOAD_URL} -O /usr/local/bin/fabio
    chmod +x /usr/local/bin/fabio
    cat > /etc/fabio/fabio.properties <<EOF
# proxy.cs configures one or more certificate sources.
#
# Each certificate source is configured with a list of
# key/value options. Each source must have a unique
# name which can then be referred to in a listener
# configuration.
#
#   cs=<name>;type=<type>;opt=arg;opt[=arg];...
#
# All certificates need to be provided in PEM format.
#
# The following types of certificate sources are available:
#
# File
#
# The file certificate source supports one certificate which is loaded at
# startup and is cached until the service exits.
#
# The 'cert' option contains the path to the certificate file. The 'key'
# option contains the path to the private key file. If the certificate file
# contains both the certificate and the private key the 'key' option can be
# omitted. The 'clientca' option contains the path to one or more client
# authentication certificates.
#
#   cs=<name>;type=file;cert=p/a-cert.pem;key=p/a-key.pem;clientca=p/clientAuth.pem
#
# Path
#
# The path certificate source loads certificates from a directory in
# alphabetical order and refreshes them periodically.
#
# The 'cert' option provides the path to the TLS certificates and the
# 'clientca' option provides the path to the certificates for client
# authentication.
#
# TLS certificates are stored either in one or two files:
#
#   www.example.com.pem or www.example.com-{cert,key}.pem
#
# TLS certificates are loaded in alphabetical order and the first certificate
# is the default for clients which do not support SNI.
#
# The 'refresh' option can be set to specify the refresh interval for the TLS
# certificates. Client authentication certificates cannot be refreshed since
# Go does not provide a mechanism for that yet.
#
# The default refresh interval is 3 seconds and cannot be lower than 1 second
# to prevent busy loops. To load the certificates only once and disable
# automatic refreshing set 'refresh' to zero.
#
#   cs=<name>;type=path;cert=path/to/certs;clientca=path/to/clientcas;refresh=3s
#
# HTTP
#
# The http certificate source loads certificates from an HTTP/HTTPS server.
#
# The 'cert' option provides a URL to a text file which contains all files
# that should be loaded from this directory. The filenames follow the same
# rules as for the path source. The text file can be generated with:
#
#   ls -1 *.pem > list
#
# The 'clientca' option provides a URL for the client authentication
# certificates analogous to the 'cert' option.
#
# Authentication credentials can be provided in the URL as request parameter,
# as basic authentication parameters or through a header.
#
# The 'refresh' option can be set to specify the refresh interval for the TLS
# certificates. Client authentication certificates cannot be refreshed since
# Go does not provide a mechanism for that yet.
#
# The default refresh interval is 3 seconds and cannot be lower than 1 second
# to prevent busy loops. To load the certificates only once and disable
# automatic refreshing set 'refresh' to zero.
#
#   cs=<name>;type=http;cert=https://host.com/path/to/cert/list&token=123
#   cs=<name>;type=http;cert=https://user:pass@host.com/path/to/cert/list
#   cs=<name>;type=http;cert=https://host.com/path/to/cert/list;hdr=Authorization: Bearer 1234
#
# Consul
#
# The consul certificate source loads certificates from consul.
#
# The 'cert' option provides a KV store URL where the the TLS certificates are
# stored.
#
# The 'clientca' option provides a URL to a path in the KV store where the the
# client authentication certificates are stored.
#
# The filenames follow the same rules as for the path source.
#
# The TLS certificates are updated automatically whenever the KV store
# changes. The client authentication certificates cannot be updated
# automatically since Go does not provide a mechanism for that yet.
#
#   cs=<name>;type=consul;cert=http://localhost:8500/v1/kv/path/to/cert&token=123
#
# Vault
#
# The Vault certificate store uses HashiCorp Vault as the certificate
# store.
#
# The 'cert' option provides the path to the TLS certificates and the
# 'clientca' option provides the path to the certificates for client
# authentication.
#
# The 'refresh' option can be set to specify the refresh interval for the TLS
# certificates. Client authentication certificates cannot be refreshed since
# Go does not provide a mechanism for that yet.
#
# The default refresh interval is 3 seconds and cannot be lower than 1 second
# to prevent busy loops. To load the certificates only once and disable
# automatic refreshing set 'refresh' to zero.
#
# The path to vault must be provided in the VAULT_ADDR environment
# variable. The token must be provided in the VAULT_TOKEN environment
# variable.
#
#   cs=<name>;type=vault;cert=secret/fabio/certs
#
#
# Common options
#
# All certificate stores support the following options:
#
#   caupgcn: Upgrade a self-signed client auth certificate with this common-name
#            to a CA certificate. Typically used for self-singed certificates
#            for the Amazon AWS Api Gateway certificates which do not have the
#            CA flag set which makes them unsuitable for client certificate
#            authentication in Go. For the AWS Api Gateway set this value
#            to 'ApiGateway' to allow client certificate authentication.
#            This replaces the deprecated parameter 'aws.apigw.cert.cn'
#            which was introduced in version 1.1.5.
#
# Examples:
#
#     # file based certificate source
#     proxy.cs = cs=some-name;type=file;cert=p/a-cert.pem;key=p/a-key.pem
#
#     # path based certificate source
#     proxy.cs = cs=some-name;type=path;path=path/to/certs
#
#     # HTTP certificate source
#     proxy.cs = cs=some-name;type=http;cert=https://user:pass@host:port/path/to/certs
#
#     # Consul certificate source
#     proxy.cs = cs=some-name;type=consul;cert=https://host:port/v1/kv/path/to/certs?token=abc123
#
#     # Vault certificate source
#     proxy.cs = cs=some-name;type=vault;cert=secret/fabio/certs
#
#     # Multiple certificate sources
#     proxy.cs = cs=srcA;type=path;path=path/to/certs,\
#                cs=srcB;type=http;cert=https://user:pass@host:port/path/to/certs
#
#     # path based certificate source for AWS Api Gateway
#     proxy.cs = cs=some-name;type=path;path=path/to/certs;clientca=path/to/clientcas;caupgcn=ApiGateway
#
# The default is
#
# proxy.cs =


# proxy.addr configures listeners.
#
# Each listener is configured with and address and a
# list of optional arguments in the form of
#
#   [host]:port;opt=arg;opt[=arg];...
#
# Each listener has a protocol which is configured
# with the 'proto' option for which it routes and
# forwards traffic.
#
# The supported protocols are:
#
#   * http for HTTP based protocols
#   * https for HTTPS based protocols
#   * tcp for a raw TCP proxy with or witout TLS support
#   * tcp+sni for an SNI aware TCP proxy
#
# If no 'proto' option is specified then the protocol
# is either 'http' or 'https' depending on whether a
# certificate source is configured via the 'cs' option
# which contains the name of the certificate source.
#
# The TCP+SNI proxy analyzes the ClientHello message
# of TLS connections to extract the server name
# extension and then forwards the encrypted traffic
# to the destination without decrypting the traffic.
#
# General options:
#
#   rt:          Sets the read timeout as a duration value (e.g. '3s')
#
#   wt:          Sets the write timeout as a duration value (e.g. '3s')
#
#   strictmatch: When set to 'true' the certificate source must provide
#                a certificate that matches the hostname for the connection
#                to be established. Otherwise, the first certificate is used
#                if no matching certificate was found. This matches the default
#                behavior of the Go TLS server implementation.
#
# TLS options:
#
#   tlsmin:      Sets the minimum TLS version for the handshake. This value
#                is one of [ssl30, tls10, tls11, tls12] or the corresponding
#                version number from https://golang.org/pkg/crypto/tls/#pkg-constants
#
#   tlsmax:      Sets the maximum TLS version for the handshake. See 'tlsmin'
#                for the format.
#
#   tlsciphers:  Sets the list of allowed ciphers for the handshake. The value
#                is a quoted comma-separated list of the hex cipher values or
#                the constant names from https://golang.org/pkg/crypto/tls/#pkg-constants,
#                e.g. "0xc00a,0xc02b" or "TLS_RSA_WITH_RC4_128_SHA,TLS_RSA_WITH_AES_128_CBC_SHA"
#
# Examples:
#
#     # HTTP listener on port 9999
#     proxy.addr = :9999
#
#     # HTTP listener on IPv4 with read timeout
#     proxy.addr = 1.2.3.4:9999;rt=3s
#
#     # HTTP listener on IPv6 with write timeout
#     proxy.addr = [2001:DB8::A/32]:9999;wt=5s
#
#     # Multiple listeners
#     proxy.addr = 1.2.3.4:9999;rt=3s,[2001:DB8::A/32]:9999;wt=5s
#
#     # HTTPS listener on port 443 with certificate source
#     proxy.addr = :443;cs=some-name
#
#     # HTTPS listener on port 443 with certificate source and TLS options
#     proxy.addr = :443;cs=some-name;tlsmin=tls10;tlsmax=tls11;tlsciphers="0xc00a,0xc02b"
#
#     # TCP listener on port 1234 with port routing
#     proxy.addr = :1234;proto=tcp
#
#     # TCP listener on port 443 with SNI routing
#     proxy.addr = :443;proto=tcp+sni
#
# The default is
#
# proxy.addr = :9999


# proxy.localip configures the ip address of the proxy which is added
# to the Header configured by header.clientip and to the 'Forwarded: by=' attribute.
#
# The local non-loopback address is detected during startup
# but can be overwritten with this property.
#
# The default is
#
# proxy.localip =


# proxy.strategy configures the load balancing strategy.
#
# rnd: pseudo-random distribution
# rr:  round-robin distribution
#
# "rnd" configures a pseudo-random distribution by using the microsecond
# fraction of the time of the request.
#
# "rr" configures a round-robin distribution.
#
# The default is
#
# proxy.strategy = rnd


# proxy.matcher configures the path matching algorithm.
#
# prefix: prefix matching
# glob:  glob matching
#
# The default is
#
# proxy.matcher = prefix


# proxy.noroutestatus configures the response code when no route was found.
#
# The default is
#
# proxy.noroutestatus = 404


# proxy.shutdownwait configures the time for a graceful shutdown.
#
# After a signal is caught the proxy will immediately suspend
# routing traffic and respond with a 503 Service Unavailable
# for the duration of the given period.
#
# The default is
#
# proxy.shutdownwait = 0s


# proxy.responseheadertimeout configures the response header timeout.
#
# This configures the ResponseHeaderTimeout of the http.Transport.
#
# The default is
#
# proxy.responseheadertimeout     = 0s


# proxy.keepalivetimeout configures the keep-alive timeout.
#
# This configures the KeepAliveTimeout of the network dialer.
#
# The default is
#
# proxy.keepalivetimeout     = 0s


# proxy.dialtimeout configures the connection timeout for
# outgoing connections.
#
# This configures the DialTimeout of the network dialer.
#
# The default is
#
# proxy.dialtimeout = 30s


# proxy.flushinterval configures periodic flushing of the
# response buffer for SSE (server-sent events) connections.
# They are detected when the 'Accept' header is
# 'text/event-stream'.
#
# The default is
#
# proxy.flushinterval = 1s


# proxy.maxconn configures the maximum number of cached
# incoming and outgoing connections.
#
# This configures the MaxConnsPerHost of the http.Transport.
#
# The default is
#
# proxy.maxconn = 10000


# proxy.header.clientip configures the header for the request ip.
#
# The remoteIP is taken from http.Request.RemoteAddr.
#
# The default is
#
# proxy.header.clientip =


# proxy.header.tls configures the header to set for TLS connections.
#
# When set to a non-empty value the proxy will set this header on every
# TLS request to the value of ${proxy.header.tls.value}
#
# The default is
#
# proxy.header.tls =
# proxy.header.tls.value =


# proxy.header.requestid configures the header for the adding a unique request id.
# When set non-empty value the proxy will set this header on every request to the
# unique UUID value.
#
# The default is
#
# proxy.header.requestid =


# proxy.gzip.contenttype configures which responses should be compressed.
#
# By default, responses sent to the client are not compressed even if the
# client accepts compressed responses by setting the 'Accept-Encoding: gzip'
# header. By setting this value responses are compressed if the Content-Type
# header of the response matches and the response is not already compressed.
# The list of compressable content types is defined as a regular expression.
# The regular expression must follow the rules outlined in golang.org/pkg/regexp.
#
# A typical example is
#
# proxy.gzip.contenttype = ^(text/.*|application/(javascript|json|font-woff|xml)|.*\+(json|xml))(;.*)?$
#
# The default is
#
# proxy.gzip.contenttype =


# log.access.format configures the format of the access log.
#
# If the value is either 'common' or 'combined' then the logs are written in
# the Common Log Format or the Combined Log Format as defined below:
#
# 'common':   $remote_host - - [$time_common] "$request" $response_status $response_body_size
# 'combined': $remote_host - - [$time_common] "$request" $response_status $response_body_size "$header.Referer" "$header.User-Agent"
#
# Otherwise, the value is interpreted as a custom log format which is defined
# with the following parameters. Providing an empty format when logging is
# enabled is an error. To disable access logging leave the log.access.target
# value empty.
#
#   $header.<name>           - request http header (name: [a-zA-Z0-9-]+)
#   $remote_addr             - host:port of remote client
#   $remote_host             - host of remote client
#   $remote_port             - port of remote client
#   $request                 - request <method> <uri> <proto>
#   $request_args            - request query parameters
#   $request_host            - request host header (aka server name)
#   $request_method          - request method
#   $request_scheme          - request scheme
#   $request_uri             - request URI
#   $request_url             - request URL
#   $request_proto           - request protocol
#   $response_body_size      - response body size in bytes
#   $response_status         - response status code
#   $response_time_ms        - response time in S.sss format
#   $response_time_us        - response time in S.ssssss format
#   $response_time_ns        - response time in S.sssssssss format
#   $time_rfc3339            - log timestamp in YYYY-MM-DDTHH:MM:SSZ format
#   $time_rfc3339_ms         - log timestamp in YYYY-MM-DDTHH:MM:SS.sssZ format
#   $time_rfc3339_us         - log timestamp in YYYY-MM-DDTHH:MM:SS.ssssssZ format
#   $time_rfc3339_ns         - log timestamp in YYYY-MM-DDTHH:MM:SS.sssssssssZ format
#   $time_unix_ms            - log timestamp in unix epoch ms
#   $time_unix_us            - log timestamp in unix epoch us
#   $time_unix_ns            - log timestamp in unix epoch ns
#   $time_common             - log timestamp in DD/MMM/YYYY:HH:MM:SS -ZZZZ
#   $upstream_addr           - host:port of upstream server
#   $upstream_host           - host of upstream server
#   $upstream_port           - port of upstream server
#   $upstream_request_scheme - upstream request scheme
#   $upstream_request_uri    - upstream request URI
#   $upstream_request_url    - upstream request URL
#   $upstream_service        - name of the upstream service
#
# The default is
#
# log.access.format = common


# log.access.target configures where the access log is written to.
#
# Options are 'stdout'. If the value is empty no access log is written.
#
# The default is
#
# log.access.target =


# log.routes.format configures the log output format of routing table updates.
#
# Changes to the routing table are written to the standard log. This option
# configures the output format:
#
# detail:   detailed routing table as ascii tree
# delta:    additions and deletions in config language
# all:      complete routing table in config language
#
# The default is
#
# log.routes.format = delta


# registry.backend configures which backend is used.
# Supported backends are: consul, static, file
#
# The default is
#
# registry.backend = consul


# registry.timeout configures how long fabio tries to connect to the registry
# backend during startup.
#
# The default is
#
# registry.timeout = 10s


# registry.retry configures the interval with which fabio tries to
# connect to the registry during startup.
#
# The default is
#
# registry.retry = 500ms


# registry.static.routes configures a static routing table.
#
# Example:
#
#     registry.static.routes = \
#       route add svc / http://1.2.3.4:5000/
#
# The default is
#
# registry.static.routes =


# registry.file.path configures a file based routing table.
# The value configures the path to the file with the routing table.
#
# The default is
#
# registry.file.path =


# registry.consul.addr configures the address of the consul agent to connect to.
#
# The default is
#
# registry.consul.addr = localhost:8500


# registry.consul.token configures the acl token for consul.
#
# The default is
#
# registry.consul.token =


# registry.consul.kvpath configures the KV path for manual routes.
#
# The consul KV path is watched for changes which get appended to
# the routing table. This allows for manual overrides and weighted
# round-robin routes.
#
# The default is
#
# registry.consul.kvpath = /fabio/config


# registry.consul.service.status configures the valid service status
# values for services included in the routing table.
#
# The values are a comma separated list of
# "passing", "warning", "critical" and "unknown"
#
# The default is
#
# registry.consul.service.status = passing


# registry.consul.tagprefix configures the prefix for tags which define routes.
#
# Services which define routes publish one or more tags with host/path
# routes which they serve. These tags must have this prefix to be
# recognized as routes.
#
# The default is
#
# registry.consul.tagprefix = urlprefix-


# registry.consul.register.enabled configures whether fabio registers itself in consul.
#
# Fabio will register itself in consul only if this value is set to "true" which
# is the default. To disable registration set it to any other value, e.g. "false"
#
# The default is
#
# registry.consul.register.enabled = true


# registry.consul.register.addr configures the address for the service registration.
#
# Fabio registers itself in consul with this host:port address.
# It must point to the UI/API endpoint configured by ui.addr and defaults to its
# value.
#
# The default is
#
# registry.consul.register.addr = :9998


# registry.consul.register.name configures the name for the service registration.
#
# Fabio registers itself in consul under this service name.
#
# The default is
#
# registry.consul.register.name = fabio


# registry.consul.register.tags configures the tags for the service registration.
#
# Fabio registers itself with these tags. You can provide a comma separated list of tags.
#
# The default is
#
# registry.consul.register.tags =


# registry.consul.register.checkInterval configures the interval for the health check.
#
# Fabio registers an http health check on http(s)://${ui.addr}/health
# and this value tells consul how often to check it.
#
# The default is
#
# registry.consul.register.checkInterval = 1s


# registry.consul.register.checkTimeout configures the timeout for the health check.
#
# Fabio registers an http health check on http(s)://${ui.addr}/health
# and this value tells consul how long to wait for a response.
#
# The default is
#
# registry.consul.register.checkTimeout = 3s


# registry.consul.register.checkTLSSkipVerify configures TLS verification for the health check.
#
# Fabio registers an http health check on http(s)://${ui.addr}/health
# and this value tells consul to skip TLS certificate validation for
# https checks.
#
# The default is
#
# registry.consul.register.checkTLSSkipVerify = false


# metrics.target configures the backend the metrics values are
# sent to.
#
# Possible values are:
#  <empty>:  do not report metrics
#  stdout:   report metrics to stdout
#  graphite: report metrics to Graphite on ${metrics.graphite.addr}
#  statsd: report metrics to StatsD on ${metrics.statsd.addr}
#  circonus: report metrics to Circonus (http://circonus.com/)
#
# The default is
#
# metrics.target =


# metrics.prefix configures the template for the prefix of all reported metrics.
#
# Each metric has a unique name which is hard-coded to
#
#    prefix.service.host.path.target-addr
#
# The value is expanded by the text/template package and provides
# the following variables:
#
#  - Hostname:  the Hostname of the server
#  - Exec:      the executable name of application
#
# The following additional functions are defined:
#
#  - clean:     lowercase value and replace '.' and ':' with '_'
#
# Template may include regular string parts to customize final prefix
#
# Example:
#
#  Server hostname: test-001.something.com
#  Binary executable name: fabio
#
#  The template variables are:
#
#  .Hostname =  test-001.something.com
#  .Exec = fabio
#
# which results to the following prefix string when using the
# default template:
#
#  test-001_something_com.fabio
#
# The default is
#
# metrics.prefix = {{clean .Hostname}}.{{clean .Exec}}


# metrics.names configures the template for the route metric names.
# The value is expanded by the text/template package and provides
# the following variables:
#
#  - Service:   the service name
#  - Host:      the host part of the URL prefix
#  - Path:      the path part of the URL prefix
#  - TargetURL: the URL of the target
#
# The following additional functions are defined:
#
#  - clean:     lowercase value and replace '.' and ':' with '_'
#
# Given a route rule of
#
#  route add testservice www.example.com/ http://10.1.2.3:12345/
#
# the template variables are:
#
#  .Service = testservice
#  .Host = www.example.com
#  .Path  = /
#  .TargetURL.Host = 10.1.2.3:12345
#
# which results to the following metric name when using the
# default template:
#
#  testservice.www_example_com./.10_1_2_3_12345
#
# The default is
#
# metrics.names = {{clean .Service}}.{{clean .Host}}.{{clean .Path}}.{{clean .TargetURL.Host}}


# metrics.interval configures the interval in which metrics are
# reported.
#
# The default is
#
# metrics.interval = 30s


# metrics.graphite.addr configures the host:port of the Graphite
# server. This is required when ${metrics.target} is set to "graphite".
#
# The default is
#
# metrics.graphite.addr =


# metrics.statsd.addr configures the host:port of the StatsD
# server. This is required when ${metrics.target} is set to "statsd".
#
# The default is
#
# metrics.statsd.addr =


# metrics.circonus.apikey configures the API token key to use when
# submitting metrics to Circonus. See: https://login.circonus.com/user/tokens
# This is required when ${metrics.target} is set to "circonus".
#
# The default is
#
# metrics.circonus.apikey =


# metrics.circonus.apiapp configures the API token app to use when
# submitting metrics to Circonus. See: https://login.circonus.com/user/tokens
# This is optional when ${metrics.target} is set to "circonus".
#
# The default is
#
# metrics.circonus.apiapp = fabio


# metrics.circonus.apiurl configures the API URL to use when
# submitting metrics to Circonus. https://api.circonus.com/v2/
# will be used if no specific URL is provided.
# This is optional when ${metrics.target} is set to "circonus".
#
# The default is
#
# metrics.circonus.apiurl =


# metrics.circonus.brokerid configures a specific broker to use when
# creating a check for submitting metrics to Circonus.
# This is optional when ${metrics.target} is set to "circonus".
# Optional for public brokers, required for Inside brokers.
# Only applicable if a check is being created.
#
# The default is
#
# metrics.circonus.brokerid =


# metrics.circonus.checkid configures a specific check to use when
# submitting metrics to Circonus.
# This is optional when ${metrics.target} is set to "circonus".
# An attempt will be made to search for a previously created check,
# if no applicable check is found, one will be created.
#
# The default is
#
# metrics.circonus.checkid =


# runtime.gogc configures GOGC (the GC target percentage).
#
# Setting runtime.gogc is equivalent to setting the GOGC
# environment variable which also takes precedence over
# the value from the config file.
#
# Increasing this value means fewer but longer GC cycles
# since there is more garbage to collect.
#
# The default of GOGC=100 works for Go 1.4 but shows
# a significant performance drop for Go 1.5 since the
# concurrent GC kicks in more often.
#
# During benchmarking I have found the following values
# to work for my setup and for now I consider them sane
# defaults for both Go 1.4 and Go 1.5.
#
# GOGC=100: Go 1.5 40% slower than Go 1.4
# GOGC=200: Go 1.5 == Go 1.4 with GOGC=100 (default)
# GOGC=800: both Go 1.4 and 1.5 significantly faster (40%/go1.4, 100%/go1.5)
#
# The default is
#
# runtime.gogc = 800


# runtime.gomaxprocs configures GOMAXPROCS.
#
# Setting runtime.gomaxprocs is equivalent to setting the GOMAXPROCS
# environment variable which also takes precedence over
# the value from the config file.
#
# If runtime.gomaxprocs < 0 then all CPU cores are used.
#
# The default is
#
# runtime.gomaxprocs = -1


# ui.access configures the access mode for the UI.
#
#  ro:  read-only access
#  rw:  read-write access
#
# The default is
#
# ui.access = rw


# ui.addr configures the address the UI is listening on.
# The listener uses the same syntax as proxy.addr but
# supports only a single listener. To enable HTTPS
# configure a certificate source. You should use
# a different certificate source than the one you
# use for the external connections, e.g. 'cs=ui'.
#
# The default is
#
# ui.addr = :9998


# ui.color configures the background color of the UI.
# Color names are from http://materializecss.com/color.html
#
# The default is
#
# ui.color = light-green


# ui.title configures an optional title for the UI.
#
# The default is
#
# ui.title =
EOF
	cat >/lib/systemd/system/fabio.service <<EOF
[Unit]
Description=Fabio Server
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=fabio
# set GOMAXPROCS to number of processors
ExecStart=/bin/bash -c "GOMAXPROCS=$(nproc) /usr/local/bin/fabio -cfg /etc/fabio/fabio.properties"
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
}

uninstall(){
    systemctl stop fabio || true
    rm -rf /usr/local/bin/fabio \
        /etc/fabio \
        /lib/systemd/system/fabio.service
    systemctl daemon-reload
    userdel fabio
}

if [ "$1" == "install" ]; then
    preinstall
    install
    postinstall
elif [ "$1" == "uninstall" ]; then
    preuninstall
    uninstall
else
    echo -e "\033[31mError: command not support!\033[0m"
    exit 1
fi
