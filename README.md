INTRODUCTION
============

Store ID helper AKA Dynamic Content Booster is scalable, enterprise-grade, high-performance
multi-threaded content deduplicator. It works with any Squid starting with v3 and with all
products based on it.

It uses standard helper protocol to interconnect with cache.

DCB supports up to 4096 threads per helper process.

INSTALLATION
============

Libraries compatibility
-----------------------

Usually helper statically linked with runtime libraries.

Note: If it built with dynamic linking, make sure your libstdc++/libc++ is at least 5.2 version. Upgrade if required first.

Squid configuration for production
----------------------------------

Unpack archive and run setup.sh (example):

```
unzip store-id-helper*.zip
setup.sh your_destination_binary_dir
```

Copy all acl.* files to your squid config dir (default is /usr/local/squid/etc) and add this to your squid.conf:

--------------- Cut --------------
```
# No cache directives
acl dont_cache_url url_regex "/usr/local/squid/etc/acl.url.nocache"
cache deny dont_cache_url

# Store rewrite ACLs
acl software_and_updates url_regex "/usr/local/squid/etc/acl.url.updates"
acl store_rewrite_list_web url_regex "/usr/local/squid/etc/acl.url.rewrite_web"
acl store_rewrite_list_web_path urlpath_regex "/usr/local/squid/etc/acl.urlpath.rewrite_web"
acl store_rewrite_list_web_cdn url_regex "/usr/local/squid/etc/acl.url.rewrite_cdn"
acl store_rewrite_list urlpath_regex "/usr/local/squid/etc/acl.urlpath.rewrite_other"

# Storeurl rewriter
store_id_program /usr/local/bin/store-id-helper
# where N should equal helper internal queue size (1024 by default)
store_id_children 4 startup=1 idle=1 concurrency=N
# Store ID access
acl store_id_get_method method GET
store_id_access deny !store_id_get_method
acl url_storeid_deny url_regex "/usr/local/squid/etc/acl.url.storeid_deny"
store_id_access deny url_storeid_deny
store_id_access allow software_and_updates
store_id_access allow store_rewrite_list_web
store_id_access allow store_rewrite_list_web_cdn
store_id_access allow store_rewrite_list_web_path
store_id_access allow store_rewrite_list
store_id_access deny all
store_id_bypass off

range_offset_limit 8192 KB !dont_cache_url all
```
--------------- Cut --------------

Adjust children value in accordingly to your load. Adjust paths to fit your setup.

Also add this refresh pattern rules on top of your refresh_patterns:

```
refresh_pattern	squidinternal	43200	100%	518400	override-expire refresh-ims reload-into-ims ignore-private store-stale ignore-no-store
```

and put all acl.* files into your squid's config directory. After all, just squid -k reconfigure and enjoy!

Vimeo autoplay/chunked caching issue
====================================

To prevent Vimeo using chunked videostreams, which leads autoplay problems and bad byte hit for videos, add this acl:

```
# Vimeo autoplay/chunked HTML5 caching issue
acl vimeo_chunked url_regex vimeo.*master\.json
http_access deny vimeo_chunked
```

anywhere above your final blocking rule and reconfigure your squid.

STORE-ID command-line options
=============================

** -d log debug to /var/log/store-id-helper.log

** -t<optional: time in ms> set debug + timing flag (when built with --enable-timing)

Note: When specified time in ms, will log only queries with timing more than specified value.

** -l<full log file name>  set log file. Default is /var/log/store-id-helper.log

Note: You should specify full path + file name. Directory should exists and has permissions to write for 
      proxy non-privileged user. If file does not exists, it will create. If file exists, it will appends.

Note: Default log, when uses, should exists and has permissions to write for proxy non-privileged user.

** -p<numeric value> - set non-default processing threads. Valid range 1..4096.

Note: If non-specified, helper internal concurrency is hardware concurrency by default. Values less than 1 is set to 1,
      values above 4096 sets to 4096 automatically.

Note: To run in 1-thread mode (for debug purposes or support legacy non-concurrent mode) just specify 0 or 1 thread.

** -q<numeric value> - set non-default thread pool queue size. Valid range 1024..8192.

Note: Queue size should be power of 2. If not - will round to nearest power of 2. Values less 1024 will always set to 1024.

** -a - turns on affinity.

Note: By default, helper builds with threads affinity support (on supported platforms, now Solaris/Linux/FreeBSD). On unsupported platforms
      this control unavailable and not shown.

Note: Affinity turned off by default. See "Affinity" below.

** -v show helper version and exit

** -h|-? show short help about command-line arguments and exit

Hardware concurrency
====================

To determine real hardware concurrency, just run tools_gethwc utility. Please, don't forget about another processes on server.

Note: Determined value will set as default helper concurrency.

Affinity
========
This option will use CPU/core affinity. Thread pool uses round-robin algorithm to bind threads across online CPU/cores.
Option useful in some cases/platforms and designed for predictive scheduling and helper latency.

Debugging
=========

To debug helper, make sure log file exists and squid has permissions to write to first:

```
# ls -al /var/log/store-id-helper.log
-rw-r--r-- 1 squid squid 809391 Feb  5 17:30 /var/log/store-id-helper.log
```

Then add -d option to helper in squid.conf:

```
store_id_program /usr/local/bin/store-id-helper -d
```

and reconfigure squid.

Now debug logging enabled. Beware, on high-load servers log grows very fast, to keep logging don't forget to
configure this log rotation too.

You can use arbitrary log file using -l command-line option (see "STORE-ID command-line options" paragraph above).

Log records structure is:

```
<-- 130 https://eus-streaming-video-msn-com.akamaized.net/ce0c0e1f-18aa-4850-9c86-1946ddbee429/198a0fab-ebe9-473c-8af7-1e5bbd2c_640x360_1092.mp4
--> 130 OK store-id=http://squidinternal.v.eus-streaming-video-msn-com/198a0fab-ebe9-473c-8af7-1e5bbd2c_640x360_1092.mp4

<Direction of query> [channel ID] <input URL>
<Direction of query> [channel ID] <helper response>
```

Trial period
============

Trial period is 30 days. After this, helper will never start.
