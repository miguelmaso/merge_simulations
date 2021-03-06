# author: Miguel Masó Sotomayor
# https://github.com/miguelmaso/merge_simulations


namespace import ::tcl::prefix
package require struct::set
package require tooltip
variable ::first_dir
variable ::second_dir
variable ::result_dir
if { ![info exists ::default_time_a] } {
    set ::default_time_a 0
}
if { ![info exists ::default_time_b] } {
    set ::default_time_b ""
}


## User interface

set w .gid.merge_settings
InitWindow $w "Merge simulations with dynamic meshes" MergeSettings
if { ![winfo exists $w] } return ;# windows disabled || usemorewindows == 0
# Definition of the widgets
ttk::labelframe $w.paths -relief flat -text "Simulation paths"
ttk::label  $w.paths.lfirst -text First
ttk::entry  $w.paths.efirst -text FirstPath -width 50 -textvariable ::first_dir
ttk::button $w.paths.bfirst -text ... -width 3 -command "selectFolder ::first_dir"
ttk::label  $w.paths.lsecond -text Second
ttk::entry  $w.paths.esecond -text SecondPath -width 50 -textvariable ::second_dir
ttk::button $w.paths.bsecond -text ... -width 3 -command "selectFolder ::second_dir"
ttk::label  $w.paths.lresult -text Result
ttk::entry  $w.paths.eresult -text ResultPath -width 50 -textvariable ::result_dir
ttk::button $w.paths.bresult -text ... -width 3 -command "selectFolder ::result_dir"
ttk::labelframe $w.times -relief flat -text "Default time steps"
ttk::label $w.times.lfirst -text First
ttk::entry $w.times.efirst -text FirstTime -width 10 -textvariable ::default_time_a
ttk::label $w.times.lsecond -text Second
ttk::entry $w.times.esecond -text SecondTime -width 10 -textvariable ::default_time_b
ttk::frame  $w.bottom
ttk::label  $w.bottom.help  -text "?" -borderwidth 2 -relief ridge -anchor center
ttk::button $w.bottom.merge -text Merge -command "main $w"
# Layout of the widgets
grid $w.paths.lfirst  $w.paths.efirst  $w.paths.bfirst  -sticky w
grid $w.paths.lsecond $w.paths.esecond $w.paths.bsecond -sticky w
grid $w.paths.lresult $w.paths.eresult $w.paths.bresult -sticky w
grid $w.paths -sticky w -padx 6 -pady 6
grid $w.times.lfirst  $w.times.efirst  -sticky w
grid $w.times.lsecond $w.times.esecond -sticky w
grid $w.times -sticky w -padx 6 -pady 6
grid $w.bottom.help $w.bottom.merge
grid $w.bottom.help -ipadx 6 -ipady 2 -padx 6
grid $w.bottom -sticky e -padx 6 -pady 6
grid rowconfigure $w 1 -weight 1
grid columnconfigure $w 0 -weight 1
# Hints for the widgets
set msg_paths "Where to read/write the post files"
set msg_times "If a time step is missing, it will be replaced by the specified time step.\nOtherwise, the time step will be skipped"
set msg_help "Merge two simulations with dynamic meshes into a third simulation.\nThe id numbering should be unique and the time labels must be shared\nby both simulations"
tooltip::tooltip $w.paths $msg_paths
tooltip::tooltip $w.times $msg_times
tooltip::tooltip $w.bottom.help $msg_help


proc selectFolder {dest_var} {
    upvar $dest_var d
    set directory [MessageBoxGetFilename directory read "Select a folder" ""]
    if {$directory != ""} {
        set d $directory
    }
}


## Procedures for merging results

proc mergeFiles {name_a name_b out_name} {
    GiD_Process files read $name_a
    GiD_Process files add $name_b
    GiD_Process files saveall binMeshesSets $out_name
}


proc mergeTimeStep {name_a name_b default_time_a default_time_b out_name time extension} {
    set full_name_a $name_a$time$extension
    set full_name_b $name_b$time$extension
    set full_out_name $out_name$time$extension
    if {[file exist $full_name_a] && [file exist $full_name_b]} {
        mergeFiles $full_name_a $full_name_b $full_out_name
    } elseif {![file exist $full_name_a] && $default_time_a != ""} {
        set full_name_a $name_a$default_time_a$extension
        mergeFiles $full_name_a $full_name_b $full_out_name
    } elseif {![file exist $full_name_b] && $default_time_b != ""} {
        set full_name_b $name_b$default_time_b$extension
        mergeFiles $full_name_a $full_name_b $full_out_name
    }
}


proc getPathTimesList {path extension} {
    set files_list [glob [file join $path *$extension]]
    set common_prefix [prefix longest $files_list ""]
    set times ""
    foreach filename $files_list {
        set current_time [string map [list $common_prefix ""] $filename]
        set current_time [string map [list $extension ""] $current_time]
        lappend times $current_time
    }
    return $times
}


proc getTimesList {first_path second_path first_default_time second_default_time extension} {
    set times_a [getPathTimesList $first_path $extension]
    set times_b [getPathTimesList $second_path $extension]
    set times ""
    if {$first_default_time != "" && $second_default_time != ""} {
        set times [::struct::set union $times_a $times_b]
    } elseif {$first_default_time == "" && $second_default_time == ""} {
        set times [::struct::set intersect $times_a $times_b]
    } elseif {$first_default_time != ""} {
        set times $times_b
    } else {
        set times $times_a
    }
    return $times
}


proc getFileName {path extension} {
    set files_list [glob [file join $path *$extension]]
    set common_prefix [prefix longest $files_list ""]
    return $common_prefix
}


proc checkOutputFileName {output_path name} {
    if {![file exist $output_path]} {
        file mkdir $output_path
    }
    set join_character _
    return [file join $output_path $name$join_character]
}


proc initializeProgress {times} {
    set ::files_read 0
    set ::total_files [llength $times]
}


proc advanceProgress {time} {
    set ::percentage [expr {100 * [incr ::files_read] / $::total_files}]
}


proc mergeSimulations {dir_a dir_b time_a time_b res_dir res_name extension} {
    set times [getTimesList $dir_a $dir_b $time_a $time_b $extension]
    set first_name [getFileName $dir_a $extension]
    set second_name [getFileName $dir_b $extension]
    set output_name [checkOutputFileName $res_dir $res_name]
    initializeProgress $times
    foreach time $times {
        mergeTimeStep $first_name $second_name $time_a $time_b $output_name $time $extension
        advanceProgress $time
    }
}


proc main {w} {
    set ::percentage 0
    GiD_Process files new Yes
    GiD_Process postprocess
    GidUtils::CreateAdvanceBar [= "Merging post-process files"] [= "Progress"] ::percentage 100
    GidUtils::DisableGraphics
    set result_name [lindex [file split $::result_dir] end]
    set extension .post.bin
    mergeSimulations $::first_dir $::second_dir $::default_time_a $::default_time_b $::result_dir $result_name $extension
    GiD_Process files new Yes
    GidUtils::EnableGraphics
    GidUtils::SetWarnLine "Files have been written to $::result_dir"
    set ::percentage 100
    destroy $w
}

