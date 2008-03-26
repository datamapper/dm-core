#!/bin/sh
#
# start/stop searchd server.

if ! [ -x /usr/local/bin/searchd ]; then
        exit 0
fi

case "$1" in
    start)
        echo -n "Starting sphinx searchd server:"
        echo -n " searchd" ; 
        /sbin/start-stop-daemon --start --quiet --pidfile /var/run/searchd.pid --chdir /etc --exec /usr/local/bin/searchd
        echo "."
        ;;
    stop)
        echo -n "Stopping sphinx searchd server:"
        echo -n " searchd" ; 
        /sbin/start-stop-daemon --stop --quiet --oknodo --pidfile /var/run/searchd.pid --exec /usr/local/bin/searchd
        echo "."
        ;;
    reload)
        echo -n "Reloading sphinx searchd server:"
        echo -n " searchd"
        /sbin/start-stop-daemon --stop --quiet --oknodo --pidfile /var/run/searchd.pid --signal 1
        echo "."
        ;;
    force-reload)
        $0 reload
        ;;
    reindex)
        cd /etc
        /usr/local/bin/indexer --rotate --quiet --all
        ;;
    restart)
        echo -n "Restarting sphinx searchd server:"
        echo -n " searchd"
        /sbin/start-stop-daemon --stop --quiet --oknodo --pidfile /var/run/searchd.pid --exec /usr/local/bin/searchd
        /sbin/start-stop-daemon --start --quiet --pidfile /var/run/searchd.pid --chdir /etc --exec  /usr/local/bin/searchd
        echo "."
        ;;
    *)
        echo "Usage: /etc/init.d/searchd {start|stop|reload|restart|reindex}"
        exit 1
        ;;
esac
exit 0
