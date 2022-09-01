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
    # Progress variables
    variable percent_read
    variable files_read
    variable total_files
    # Initialization with default values
    if {![info exists default_time_a]} {
        set default_time_a 0
    }
    if {![info exists default_time_b]} {
        set default_time_b ""
    }
}

########################################################
#################### User interface ####################
########################################################

proc MergeSimulations::Merge { } {
    # Window creation
    set w .gid.merge_settings
    InitWindow $w "Merge simulations with dynamic meshes" MergeSettings
    if { ![winfo exists $w] } return ;# windows disabled || usemorewindows == 0
    # Definition of the widgets
    ttk::labelframe $w.paths -relief flat -text "Simulation paths"
    ttk::label  $w.paths.lfirst -text First
    ttk::entry  $w.paths.efirst -text FirstPath -width 50 -textvariable MergeSimulations::first_dir
    ttk::button $w.paths.bfirst -text ... -width 3 -command "MergeSimulations::selectFolder MergeSimulations::first_dir"
    ttk::label  $w.paths.lsecond -text Second
    ttk::entry  $w.paths.esecond -text SecondPath -width 50 -textvariable MergeSimulations::second_dir
    ttk::button $w.paths.bsecond -text ... -width 3 -command "MergeSimulations::selectFolder MergeSimulations::second_dir"
    ttk::label  $w.paths.lresult -text Result
    ttk::entry  $w.paths.eresult -text ResultPath -width 50 -textvariable MergeSimulations::result_dir
    ttk::button $w.paths.bresult -text ... -width 3 -command "MergeSimulations::selectFolder MergeSimulations::result_dir"
    ttk::labelframe $w.times -relief flat -text "Default time steps"
    ttk::label $w.times.lfirst -text First
    ttk::entry $w.times.efirst -text FirstTime -width 10 -textvariable MergeSimulations::default_time_a
    ttk::label $w.times.lsecond -text Second
    ttk::entry $w.times.esecond -text SecondTime -width 10 -textvariable MergeSimulations::default_time_b
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
    # Merge two simulations given the full names with a time stamp
    GiD_Process files read $name_a
    GiD_Process files add $name_b
    GiD_Process files saveall binMeshesSets $out_name
}

proc MergeSimulations::mergeTimeStep {name_a name_b time out_name extension} {
    # Merge two simulations at the specified time
    # 
    set full_name_a $name_a$time$extension
    set full_name_b $name_b$time$extension
    set full_out_name $out_name$time$extension
    if {[file exist $full_name_a] && [file exist $full_name_b]} { # First case: both files exist
        mergeFiles $full_name_a $full_name_b $full_out_name
    } elseif {![file exist $full_name_a] && $MergeSimulations::default_time_a != ""} { # Second case: replace the first file by the default time
        set full_name_a $name_a$MergeSimulations::default_time_a$extension
        mergeFiles $full_name_a $full_name_b $full_out_name
    } elseif {![file exist $full_name_b] && $MergeSimulations::default_time_b != ""} { # Third case: replace the second file by the default time
        set full_name_b $name_b$MergeSimulations::default_time_b$extension
        mergeFiles $full_name_a $full_name_b $full_out_name
    }
    # Fourth case: skip this time step
}

proc MergeSimulations::getPathTimesList {path extension} {
    # Get all the time stamps inside a folder with a given extension
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
    # Ge the common time stapms from two directories. If a default time is present the intersection will be extended
    set times_a [getPathTimesList $MergeSimulations::first_dir $extension]
    set times_b [getPathTimesList $MergeSimulations::second_dir $extension]
    set times ""
    if {$MergeSimulations::default_time_a == "" && $MergeSimulations::default_time_b == ""} {
        set times [::struct::set intersect $times_a $times_b]
    } elseif {$MergeSimulations::default_time_a != "" && $MergeSimulations::default_time_b != ""} {
        set times [::struct::set union $times_a $times_b]
    } elseif {$MergeSimulations::default_time_a != ""} {
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
    # Get the list of steps/times
    set times [getTimesList $extension]
    # Get the names of the files without the time stamp
    set first_name [getFileName $MergeSimulations::first_dir $extension]
    set second_name [getFileName $MergeSimulations::second_dir $extension]
    set output_name [checkOutputFileName $MergeSimulations::result_dir $result_name]
    # Merge each step
    initializeProgress $times
    foreach time $times {
        mergeTimeStep $first_name $second_name $time $output_name $extension
        advanceProgress $time
    }
}

proc MergeSimulations::executeMerge {w} {
    # Clean the window, initialize the progress bar and disable the graphics
    GiD_Process files new Yes
    set MergeSimulations::percent_read 0
    GidUtils::CreateAdvanceBar [= "Merging post-process files"] [= "Progress"] MergeSimulations::percent_read 100
    GidUtils::DisableGraphics
    # Get the name of the results folder
    set result_name [lindex [file split $MergeSimulations::result_dir] end]
    set extension .post.bin
    mergeSimulations $result_name $extension
    # Restore the session
    GiD_Process files new Yes
    GidUtils::EnableGraphics
    GidUtils::SetWarnLine "MergeSimulations. Files have been written to $MergeSimulations::result_dir"
    set MergeSimulations::percent_read 100
    destroy $w
}

########################################################
################# Plug-in registration #################
########################################################

proc MergeSimulations::AddToMenu { } {   
    if { [GidUtils::IsTkDisabled] } {
        return
    }
    if { [GiDMenu::GetOptionIndex Files [list "Merge simulations..."] POST] == -1 } {       
        # Try to insert this menu after the word "Files->Export"
        set position [GiDMenu::GetOptionIndex Files [list "Export"] POST]
        if { $position == -1 } {
            set position end
        }
        GiDMenu::InsertOption Files [list "Merge simulations..."] $position POST MergeSimulations::Merge "" "" insertafter _
    }
}

# Invoke this menus changes
MergeSimulations::AddToMenu
GiDMenu::UpdateMenus
