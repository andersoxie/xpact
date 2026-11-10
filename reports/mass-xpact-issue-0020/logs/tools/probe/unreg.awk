# unreg.awk: per generated C function, print it when it has EIF_REFERENCE locals (locN / trN),
# makes calls, but has no RTLD (no GC registration of its locals). mass-xpact #20.
{ sub(/\r$/, "") }
/^\/\* \{.*\}\..* \*\/$/ { name = $0; next }
/^[A-Za-z].*\(EIF_REFERENCE Current.*\)$/ { infn = 1; reflocal = 0; rtld = 0; calls = 0; fn = name; next }
infn && /^\}/ { if (reflocal && !rtld && calls) print fn; infn = 0; next }
infn && /EIF_REFERENCE (loc[0-9]+|tr[0-9]+) / { reflocal = 1 }
infn && /RTLD;/ { rtld = 1 }
infn && /[FR][0-9]+_?[0-9]*(\[|\()/ { calls = 1 }
