set ::env(PATH) "C:/Program Files/Git/usr/bin;$::env(PATH)"

rename exec _original_exec
proc exec {args} {
    set cmd [lindex $args 0]
    if {$cmd eq "kill"} {
        set pid [lindex $args end]
        catch { _original_exec taskkill.exe /F /T /PID $pid }
        return ""
    }
    return [uplevel 1 _original_exec $args]
}

