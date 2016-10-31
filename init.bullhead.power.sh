#!/system/bin/sh

################################################################################
# helper functions to allow Android init like script

function write() {
    echo -n $2 > $1
}

function copy() {
    cat $1 > $2
}

function get-set-forall() {
    for f in $1 ; do
        cat $f
        write $f $2
    done
}

################################################################################

# take the A57s offline when thermal hotplug is disabled
write /sys/devices/system/cpu/cpu4/online 0
write /sys/devices/system/cpu/cpu5/online 0

# disable thermal bcl hotplug to switch governor
write /sys/module/msm_thermal/core_control/enabled 0
get-set-forall /sys/devices/soc.0/qcom,bcl.*/mode disable
bcl_hotplug_mask=`get-set-forall /sys/devices/soc.0/qcom,bcl.*/hotplug_mask 0`
bcl_hotplug_soc_mask=`get-set-forall /sys/devices/soc.0/qcom,bcl.*/hotplug_soc_mask 0`
get-set-forall /sys/devices/soc.0/qcom,bcl.*/mode enable

# some files in /sys/devices/system/cpu are created after the restorecon of
# /sys/. These files receive the default label "sysfs".
# Restorecon again to give new files the correct label.
restorecon -R /sys/devices/system/cpu

# Best effort limiting for first time boot if msm_performance module is absent
write /sys/devices/system/cpu/cpu4/cpufreq/scaling_max_freq 1248000

# Limit A57 max freq from msm_perf module in case CPU 4 is offline
write /sys/module/msm_performance/parameters/cpu_max_freq "4:960000 5:960000"

# Disable CPU retention
write /sys/module/lpm_levels/system/a53/cpu0/retention/idle_enabled 0
write /sys/module/lpm_levels/system/a53/cpu1/retention/idle_enabled 0
write /sys/module/lpm_levels/system/a53/cpu2/retention/idle_enabled 0
write /sys/module/lpm_levels/system/a53/cpu3/retention/idle_enabled 0
write /sys/module/lpm_levels/system/a57/cpu4/retention/idle_enabled 0
write /sys/module/lpm_levels/system/a57/cpu5/retention/idle_enabled 0

# Disable L2 retention
write /sys/module/lpm_levels/system/a53/a53-l2-retention/idle_enabled 0
write /sys/module/lpm_levels/system/a57/a57-l2-retention/idle_enabled 0

# configure governor settings for little cluster
write /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor impulse
restorecon -R /sys/devices/system/cpu # must restore after impulse
write /sys/devices/system/cpu/cpu0/cpufreq/impulse/timer_slack 80000
write /sys/devices/system/cpu/cpu0/cpufreq/impulse/timer_rate 20000
write /sys/devices/system/cpu/cpu0/cpufreq/impulse/target_loads 90
write /sys/devices/system/cpu/cpu0/cpufreq/impulse/min_sample_time 80000
write /sys/devices/system/cpu/cpu0/cpufreq/impulse/hispeed_freq 1440000
write /sys/devices/system/cpu/cpu0/cpufreq/impulse/go_hispeed_load 99
write /sys/devices/system/cpu/cpu0/cpufreq/impulse/above_hispeed_delay 20000
write /sys/devices/system/cpu/cpu0/cpufreq/impulse/align_windows 0
write /sys/devices/system/cpu/cpu0/cpufreq/impulse/max_freq_hysteresis 0
write /sys/devices/system/cpu/cpu0/cpufreq/impulse/powersave_bias 0

# online CPU4
write /sys/devices/system/cpu/cpu4/online 1

# configure governor settings for big cluster
write /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor ironactive
restorecon -R /sys/devices/system/cpu # must restore after ironactive
write /sys/devices/system/cpu/cpu4/cpufreq/ironactive/go_hispeed_load 90
write /sys/devices/system/cpu/cpu4/cpufreq/ironactive/above_hispeed_delay 0
write /sys/devices/system/cpu/cpu4/cpufreq/ironactive/timer_rate 20000
write /sys/devices/system/cpu/cpu4/cpufreq/ironactive/hispeed_freq 1440000
write /sys/devices/system/cpu/cpu4/cpufreq/ironactive/timer_slack -1
write /sys/devices/system/cpu/cpu4/cpufreq/ironactive/target_loads "74 768000:73 864000:64 960000:80 1248000:61 1344000:69 1440000:64 1536000:74 1632000:69 1689600:67 1824000:72"
write /sys/devices/system/cpu/cpu4/cpufreq/ironactive/min_sample_time 30000
write /sys/devices/system/cpu/cpu4/cpufreq/ironactive/boost 0
write /sys/devices/system/cpu/cpu4/cpufreq/ironactive/align_windows 0
write /sys/devices/system/cpu/cpu4/cpufreq/ironactive/use_migration_notif 1
write /sys/devices/system/cpu/cpu4/cpufreq/ironactive/use_sched_load 0
write /sys/devices/system/cpu/cpu4/cpufreq/ironactive/max_freq_hysteresis 20000
write /sys/devices/system/cpu/cpu4/cpufreq/ironactive/boostpulse_duration 80000

# restore A57's max
copy /sys/devices/system/cpu/cpu4/cpufreq/cpuinfo_max_freq /sys/devices/system/cpu/cpu4/cpufreq/scaling_max_freq

# plugin remaining A57s
write /sys/devices/system/cpu/cpu5/online 1

# Restore CPU 4 max freq from msm_performance
write /sys/module/msm_performance/parameters/cpu_max_freq "4:4294967295 5:4294967295"

# input boost configuration
write /sys/module/cpu_boost/parameters/input_boost_enabled 1
write /sys/module/cpu_boost/parameters/input_boost_freq 0:600000 1:600000 2:600000 3:600000 4:0 5:0
write /sys/module/cpu_boost/parameters/input_boost_ms 40

# Setting B.L scheduler parameters
write /proc/sys/kernel/sched_migration_fixup 1
write /proc/sys/kernel/sched_upmigrate 95
write /proc/sys/kernel/sched_downmigrate 85
write /proc/sys/kernel/sched_freq_inc_notify 400000
write /proc/sys/kernel/sched_freq_dec_notify 400000

#enable rps static configuration
write /sys/class/net/rmnet_ipa0/queues/rx-0/rps_cpus 8

# android background processes are set to nice 10. Never schedule these on the a57s.
write /proc/sys/kernel/sched_upmigrate_min_nice 9

get-set-forall  /sys/class/devfreq/qcom,cpubw*/governor bw_hwmon

# Disable sched_boost
write /proc/sys/kernel/sched_boost 0

# re-enable thermal and BCL hotplug
write /sys/module/msm_thermal/core_control/enabled 1
get-set-forall /sys/devices/soc.0/qcom,bcl.*/mode disable
get-set-forall /sys/devices/soc.0/qcom,bcl.*/hotplug_mask $bcl_hotplug_mask
get-set-forall /sys/devices/soc.0/qcom,bcl.*/hotplug_soc_mask $bcl_hotplug_soc_mask
get-set-forall /sys/devices/soc.0/qcom,bcl.*/mode enable

# set GPU default power level to 5 (180MHz) instead of 4 (305MHz)
write /sys/class/kgsl/kgsl-3d0/default_pwrlevel 5
