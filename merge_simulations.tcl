# author: Miguel Masó Sotomayor
# https://github.com/miguelmaso/merge_simulations


namespace import ::tcl::prefix
package require struct::set
package require tooltip


namespace eval MergeSimulations {
    # Path variables
    variable first_dir
    variable second_dir
    variable result_dir
    variable default_time_a
    variable default_time_b
    if {![info exists default_time_a]} {
        set default_time_a 0
    }
    if {![info exists default_time_b]} {
        set default_time_b ""
    }
    # Progress variables
    variable percent_done
    variable files_read
    variable total_files
}


proc MergeSimulations::Init { } {
}


########################################################
#################### User interface ####################
########################################################

proc MergeSimulations::Merge { } {
    variable first_dir
    variable second_dir
    variable result_dir
    variable default_time_a
    variable default_time_b
    # Window creation
    set w .gid.merge_settings
    InitWindow $w "Merge simulations with dynamic meshes" MergeSettings
    if { ![winfo exists $w] } return ;# windows disabled || usemorewindows == 0
    # Definition of the widgets
    ttk::labelframe $w.paths -relief flat -text "Simulation paths"
    ttk::label  $w.paths.lfirst -text First
    ttk::entry  $w.paths.efirst -text FirstPath -width 50 -textvariable first_dir
    ttk::button $w.paths.bfirst -text ... -width 3 -command "MergeSimulations::selectFolder first_dir"
    ttk::label  $w.paths.lsecond -text Second
    ttk::entry  $w.paths.esecond -text SecondPath -width 50 -textvariable second_dir
    ttk::button $w.paths.bsecond -text ... -width 3 -command "MergeSimulations::selectFolder second_dir"
    ttk::label  $w.paths.lresult -text Result
    ttk::entry  $w.paths.eresult -text ResultPath -width 50 -textvariable result_dir
    ttk::button $w.paths.bresult -text ... -width 3 -command "MergeSimulations::selectFolder result_dir"
    ttk::labelframe $w.times -relief flat -text "Default time steps"
    ttk::label $w.times.lfirst -text First
    ttk::entry $w.times.efirst -text FirstTime -width 10 -textvariable default_time_a
    ttk::label $w.times.lsecond -text Second
    ttk::entry $w.times.esecond -text SecondTime -width 10 -textvariable default_time_b
    ttk::frame  $w.bottom
    ttk::label  $w.bottom.help  -text "?" -borderwidth 2 -relief ridge -anchor center
    ttk::button $w.bottom.merge -text Merge -command "MergeSimulations::executeMerge $w"
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
}


proc MergeSimulations::selectFolder {dest_var} {
    upvar $dest_var d
    set directory [MessageBoxGetFilename directory read "Select a folder" ""]
    if {$directory != ""} {
        set d $directory
    }
}


########################################################
################### Merge procedures ###################
########################################################

proc MergeSimulations::mergeFiles {name_a name_b out_name} {
    GiD_Process files read $name_a
    GiD_Process files add $name_b
    GiD_Process files saveall binMeshesSets $out_name
}


proc MergeSimulations::mergeTimeStep {name_a name_b time out_name extension} {
    variable default_time_a
    variable default_time_b
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


proc MergeSimulations::getPathTimesList {path extension} {
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


proc MergeSimulations::getTimesList {extension} {
    variable first_dir
    variable second_dir
    variable default_time_a
    variable default_time_b
    set times_a [getPathTimesList $first_dir $extension]
    set times_b [getPathTimesList $second_dir $extension]
    set times ""
    if {$default_time_a != "" && $default_time_b != ""} {
        set times [::struct::set union $times_a $times_b]
    } elseif {$default_time_a == "" && $default_time_b == ""} {
        set times [::struct::set intersect $times_a $times_b]
    } elseif {$default_time_a != ""} {
        set times $times_b
    } else {
        set times $times_a
    }
    return $times
}


proc MergeSimulations::getFileName {path extension} {
    set files_list [glob [file join $path *$extension]]
    set common_prefix [prefix longest $files_list ""]
    return $common_prefix
}


proc MergeSimulations::checkOutputFileName {output_path name} {
    if {![file exist $output_path]} {
        file mkdir $output_path
    }
    set join_character _
    return [file join $output_path $name$join_character]
}


proc MergeSimulations::initializeProgress {times} {
    set MergeSimulations::files_read 0
    set MergeSimulations::total_files [llength $times]
}


proc MergeSimulations::advanceProgress {time} {
    set MergeSimulations::percent_read [expr {100 * [incr MergeSimulations::files_read] / $MergeSimulations::total_files}]
}


proc MergeSimulations::mergeSimulations {result_name extension} {
    variable first_dir
    variable second_dir
    variable result_dir
    set times [getTimesList $extension]
    set first_name [getFileName $first_dir $extension]
    set second_name [getFileName $second_dir $extension]
    set output_name [checkOutputFileName $result_dir $result_name]
    initializeProgress $times
    foreach time $times {
        mergeTimeStep $first_name $second_name $time $output_name $extension
        advanceProgress $time
    }
}


proc MergeSimulations::executeMerge {w} {
    variable result_dir
    variable percent_read
    set percent_read 0
    GiD_Process files new Yes
    GiD_Process postprocess
    GidUtils::CreateAdvanceBar [= "Merging post-process files"] [= "Progress"] percent_read 100
    GidUtils::DisableGraphics
    set result_name [lindex [file split $result_dir] end]
    set extension .post.bin
    MergeSimulations::mergeSimulations $result_name $extension
    GiD_Process files new Yes
    GidUtils::EnableGraphics
    GidUtils::SetWarnLine "Files have been written to $result_dir"
    set percent_read 100
    destroy $w
}


########################################################
################# Plug-in registration #################
########################################################

proc MergeSimulations::AddToMenuPOST { } {   
    if { [GidUtils::IsTkDisabled] } {
        return
    }
    if { [GiDMenu::GetOptionIndex Files [list "MergeSimulations..."] POST] == -1 } {       
        # Try to insert this menu after the word "Files->Export"
        set position [GiDMenu::GetOptionIndex Files [list "Export"] POST]
        if { $position == -1 } {
            set position end
        }
        GiDMenu::InsertOption Files [list "MergeSimulations..."] $position POST MergeSimulations::Merge "" "" insertafter _
    }
}


proc MergeSimulations::AddToMenu { } {
    MergeSimulations::AddToMenuPOST
}


MergeSimulations::Init

# Invoke this menus changes
MergeSimulations::AddToMenu
GiDMenu::UpdateMenus
