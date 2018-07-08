INTRODUCTION
============

Store ID helper AKA Dynamic Content Booster is scalable, enterprise-grade, high-performance
multi-threaded content deduplicator. It works with any Squid starting with v3 and with all
products based on it.

It uses standard helper protocol to interconnect with cache.

DCB supports up to 4096 threads per helper process by default.

INSTALLATION
============

Libraries compatibility
-----------------------

Make sure your libstdc++ is at least 5.2 version. Upgrade if required first.

Squid configuration for production
----------------------------------

Unpack archive and run setup.sh (example):

unzip store-id-helper*.zip
setup.sh your_destination_binary_dir

Copy all acl.* files to your squid config dir (default is /usr/local/squid/etc) and add this to your squid.conf:

--------------- Cut --------------
\# No cache directives
acl dont_cache_url url_regex "/usr/local/squid/etc/acl.url.nocache"
cache deny dont_cache_url

\# Store rewrite ACLs
acl software_and_updates url_regex "/usr/local/squid/etc/acl.url.updates"
acl store_rewrite_list_web url_regex "/usr/local/squid/etc/acl.url.rewrite_web"
acl store_rewrite_list_web_path urlpath_regex "/usr/local/squid/etc/acl.urlpath.rewrite_web"
acl store_rewrite_list_web_cdn url_regex "/usr/local/squid/etc/acl.url.rewrite_cdn"
acl store_rewrite_list urlpath_regex "/usr/local/squid/etc/acl.urlpath.rewrite_other"

\# Storeurl rewriter
store_id_program /usr/local/bin/store-id-helper
\# Squid 3.5+
store_id_children 4 startup=1 idle=1 concurrency=1024
\# Squid 4+
\#store_id_children 4 startup=1 idle=1 concurrency=1024 queue-size=64
\# Store ID access
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
--------------- Cut --------------

Adjust children value in accordingly to your load. Adjust paths to fit your setup.

Also add this refresh pattern rules on top of your refresh_patterns:

refresh_pattern	squidinternal	43200	100%	518400	override-expire refresh-ims reload-into-ims ignore-private store-stale ignore-no-store

and put all acl.* files into your squid's config directory. After all, just squid -k reconfigure and enjoy!

Vimeo autoplay/chunked caching issue
====================================

To prevent Vimeo using chunked videostreams, which leads autoplay problems and bad byte hit for videos, add this acl:

\# Vimeo autoplay/chunked HTML5 caching issue
acl vimeo_chunked url_regex vimeo.*master\.json
http_access deny vimeo_chunked

anywhere above your final blocking rule and reconfigure your squid.

STORE-ID command-line options
=============================

** -d log debug to /var/log/store-id-helper.log
** -t set debug + timing flag (when built with -DTIME)

** -l<full log file name>  set log file. Default is /var/log/store-id-helper.log
Note: You should specify full path + file name. Directory should exists and has permissions to write for 
      proxy non-privileged user. If file does not exists, it will create. If file exists, it will appends.
Note: Default log, when uses, should exists and has permissions to write for proxy non-privileged user.

** -p<numeric value> - set non-default processing threads. Valid range 1..4096.
Note: If non-specified, helper internal concurrency is hardware concurrency by default. Values less than 1 is set to 1,
      values above 4096 sets to 4096 automatically.
Note: To run in 1-thread mode (for debug purposes or support legacy non-concurrent mode) just specify 0 or 1 thread.

** -q<numeric value> - set non-default thread pool queue size. Valid range (threads * 64)..262144.

Note: Queue size should be power of 2. If not - will round to nearest power of 2. Values less (threads * 64) will always set to (threads * 64).
Note: Careful with -p and -q options! In general, this values is set in according with concurrency= parameter in store_id_children
      and should not be too high. Concurrency, however, better to set several times higher than pool size/internal queue size value.

** -v show helper version and exit
** -h|-? show short help about command-line arguments and exit

Hardware concurrency
====================

To determine real hardware concurrency, just run tools_gethwc utility. Please, don't forget about another processes on server.
Note: Determined value will set as default helper concurrency.

Debugging
=========

To debug helper, make sure log file exists and squid has permissions to write to first:

\# ls -al /var/log/store-id-helper.log
-rw-r--r-- 1 squid squid 809391 Feb  5 17:30 /var/log/store-id-helper.log

Then add -d option to helper in squid.conf:

store_id_program /usr/local/bin/store-id-helper -d

and reconfigure squid.

Now debug logging enabled. Beware, on high-load servers log grows very fast, to keep logging don't forget to
configure this log rotation too.

You can use arbitrary log file using -l command-line option (see "STORE-ID command-line options" paragraph above).

Log records structure is:

<-- 130 https://136skyfiregce-a.akamaihd.net/exp=1486297811~acl=%2F192156335%2F%2A~hmac=2493c8d048eb5997a1aacdcf09a388325a2b992fa2f605554e1b576c1b748341/192156335/video/640352241/chop/segment-52.m4s
--> 130 OK store-id=http://squidinternal.video-srv.vimeo/192156335/video/640352241/chop/segment-52.m4s

<Direction of query> [channel ID] <input URL>
<Direction of query> [channel ID] <helper response>

Trial period
============

Trial period is 30 days. After this, helper will never start.
