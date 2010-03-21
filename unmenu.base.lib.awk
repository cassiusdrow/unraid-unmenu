function GetArrayStatus(a, d) {
    RS="\n"
    array_numdisks=0
    numdisks=0
    last_parity_sync=0
    resync_percentage=""
    resync_finish=""
    resync_speed=""
    resync_pos=""
    last_parity_errs=0
    array_state="Not started"
    has_spinup="false"

    while (("/root/mdcmd status|strings" | getline a) > 0 ) {
        # number of disks in the superblock
        if ( a ~ "sbNumDisks" )      { delete d; split(a,d,"="); numdisks=d[2] }
        # number of disks in the "md" array
        if ( a ~ "mdNumProtected" )  { delete d; split(a,d,"="); array_numdisks=d[2] }
        # datetime (in seconds) of last parity sync
        if ( a ~ "sbSynced" )        { delete d; split(a,d,"="); last_parity_sync=d[2] }
        # number of errors detected in last parity sync
        if ( a ~ "sbSyncErrs" )      { delete d; split(a,d,"="); last_parity_errs=d[2] }
        # percentage of sync completed thus far
        if ( a ~ "mdResyncPrcnt" )   { delete d; split(a,d,"="); resync_percentage=d[2] }
        if ( a ~ "mdResyncFinish" )  { delete d; split(a,d,"="); resync_finish=d[2] }
        if ( a ~ "mdResyncSpeed" )   { delete d; split(a,d,"="); resync_speed=d[2] }
        if ( a ~ "mdResyncPos" )     { delete d; split(a,d,"="); resync_pos=d[2] }
        # array status
        if ( a ~ "mdState" )         { delete d; split(a,d,"="); array_state=d[2] }
        # per disk data, stored in disk_... arrays, delete "ata-" preface on disk_id.
        if ( a ~ "diskName" )        { delete d; split(a,d,"[.=]"); disk_name[d[2]]=d[3]; }
        if ( a ~ "diskId" )          { delete d; split(a,d,"[.=]"); offset = index(d[3],"-")+1; 
                                                 disk_id[d[2]]=substr(d[3],offset); }
        if ( a ~ "diskSerial" )      { delete d; split(a,d,"[.=]"); disk_serial[d[2]]=d[3]; }
        if ( a ~ "diskSize" )        { delete d; split(a,d,"[.=]"); disk_size[d[2]]=d[3]; }
        if ( a ~ "rdevSize" )        { delete d; split(a,d,"[.=]"); rdisk_size[d[2]]=d[3]; }   #bjp999
        if ( a ~ "rdevSerial" )      { delete d; split(a,d,"[.=]"); rdisk_serial[d[2]]=d[3]; }
        if ( a ~ "diskModel" )       { delete d; split(a,d,"[.=]"); disk_model[d[2]]=d[3]; }
        if ( a ~ "rdevModel" )       { delete d; split(a,d,"[.=]"); rdisk_model[d[2]]=d[3]; }
        if ( a ~ "rdevStatus" )      { delete d; split(a,d,"[.=]"); disk_status[d[2]]=d[3]; }
        if ( a ~ "rdevName" )        { delete d; split(a,d,"[.=]"); disk_device[d[2]]=d[3]; 
                                       if ( disk_device[d[2]] != "" ) GetReadWriteStats(d[2])
                                     }
        if ( a ~ "rdevLastIO" )      { delete d; split(a,d,"[.=]"); rdisk_lastIO[d[2]]=d[3]; }
        #if ( a ~ "diskNumWrites" )   { delete d; split(a,d,"[.=]"); disk_writes[d[2]]=d[3]; }
        #if ( a ~ "diskNumReads" )    { delete d; split(a,d,"[.=]"); disk_reads[d[2]]=d[3]; }
        if ( a ~ "diskNumErrors" )   { delete d; split(a,d,"[.=]"); disk_errors[d[2]]=d[3]; }
        if ( a ~ "rdevSpinupGroup" ) { has_spinup="true"; }

    }
    close("/root/mdcmd status|strings")
}

function GetDiskData(cmd, a, d, line, s, i) {
  # read from /proc/partitions
    RS="\n"
    cmd="cat /proc/partitions | grep -v '^major' | grep -v '^$' "
    num_partitions=0
    while ((cmd | getline a) > 0 ) {
        num_partitions++
        delete d;
        split(a,d," ");    
        major[num_partitions] = d[1]
        minor[num_partitions] = d[2]
        blocks[num_partitions] = d[3]
        device[num_partitions] = d[4]
        assigned[num_partitions] = ""
        mounted[num_partitions] = ""
        model_serial[num_partitions] = ""
    }
    close(cmd)

    # Now, identify the UNRAID device... It should be available in /dev/disk/by-label
    cmd="ls -l /dev/disk/by-label | grep 'UNRAID'"
    while ((cmd | getline a) > 0 ) {
        delete d;
        split(a,d," ");    
        sub("../../","",d[11])
        unraid_volume=d[11]
    }
    close(cmd);

    # match the device to the volume labeled UNRAID
    for( a = 0; a < num_partitions; a++ ) {
        if ( device[a] == unraid_volume ) {
             assigned[a] = "UNRAID"
        }     
    }

    # Now, get the model/serial numbers. They should be available in /dev/disk/id-label
    cmd="ls -l /dev/disk/by-id"
    while ((cmd | getline line) > 0 ) {
       delete d;
       split(line,d," ");    
       sub("../../","",d[11])
       for( a = 0; a < num_partitions; a++ ) {
           if ( d[11] == ( device[a] ) ) {
               if(model_serial[a] != "")  # bjp999 - don't overwrite "ata-" flavor with "scsi-" flavor
                  break;                  # bjp999

               model_serial[a]=d[9]
               sub("-part1","", model_serial[a])
               sub("ata-","", model_serial[a])
               break;
           }
       }
    }
    close(cmd);

    # determine if partitions are mounted anywhere
    RS="\n"
    cmd = "mount"
    while ((cmd | getline line) > 0 ) {
       delete s;
       split(line,s," ");
       for( a = 0; a < num_partitions; a++ ) {
           if ( s[1] == ( "/dev/" device[a] ) ) {
               mounted[a]=s[3]
               break;
           }
       }
    }
    close(cmd);

    # if the partition is part of the managed array, mark it as "in-array"
    # mark the full disk partition as in-array too if matched first three characters.
    for( a = 1; a <= num_partitions; a++ ) {
        for ( i =0; i<numdisks; i++ ) {
            if ( disk_device[i] == substr(device[a],1,3) || disk_name[i] == device[a] ) {
                assigned[a] = "in-array"
            }
        }
       if ( mounted[a] == "/boot" ) {
          boot_device=device[a]
       }
    }
    # mark the boot partitons as "in-array"
    for( a = 1; a <= num_partitions; a++ ) {

       if(assigned[a] != "in-array")                           #bjp999
          GetReadWriteStatsOther( a, substr(device[a],1,3) );  #bjp999
       else                                                    #bjp999
       if ( substr(boot_device,1,3) == device[a] ) {
                assigned[a] = "in-array"
       }
    }
    # Get the shares
    delete SHARES
    RS="\n"
    cmd = "smbclient -N -L localhost 2>/dev/null"
    while ((cmd | getline line) > 0 ) {
       delete s;
       split(line,s," ");
       if ( s[2] == "Disk" ) {
          SHARES[s[1]] = s[1]
       }
    }
    close(cmd);
}


function CGI_setup( uri, version, i, j) {
  delete GETARG;         delete MENU;        delete PARAM

  gsub("+", " ", ARGV[3])
  gsub("%24", "$", ARGV[3])
  gsub("%2F", "/", ARGV[3])
  gsub("%21", "!", ARGV[3])
  gsub("%2B", "+", ARGV[3])
  gsub("%5C", "\\", ARGV[3])
  n=gsub("%A0", amp "nbsp;", ARGV[3])

  GETARG["Status"] = ARGV[1]; GETARG["Method"] = ARGV[2]; GETARG["URI"] = ARGV[3]; 
  i = index(ARGV[3], "?")
  if (i > 0) {             # is there a "?" indicating a CGI request?
    split(substr(ARGV[3], 1, i-1), MENU, "[/:]")
    split(substr(ARGV[3], i+1), PARAM, "&")
    for (i in PARAM) {
      j = index(PARAM[i], "=")
      GETARG[substr(PARAM[i], 1, j-1)] = substr(PARAM[i], j+1)
    }
  } else {             # there is no "?", no need for splitting PARAMs
    split(ARGV[3], MENU, "[/:]")
  }
}


function GetRawDiskBlocks( theDisk, partition, a, s, d_size, cmd) {
   if(constant["minrawsectors"] != "")
      return(constant["minrawsectors"]);

    d_size = ""
    cmd = "fdisk -l " theDisk
    RS="\n"
    while ((cmd | getline a) > 0 ) {
        if ( a ~ theDisk ) {
            delete s;
            split(a,s," ");
            d_size=s[5]
            break;
        }
    }
    close(cmd);
    return ( d_size / 1024 )
}

function GetReadWriteStats(theDevIndex, cmd) {
  cmd="cat /sys/block/" disk_device[theDevIndex] "/stat"
  cmd | getline
  disk_reads[theDevIndex] = $1
  disk_writes[theDevIndex] = $5
  close(cmd)
}

function GetReadWriteStatsOther(theDevIndex, theDevice, cmd) { #bjp999
  cmd="cat /sys/block/" theDevice "/stat"                      #bjp999 
  cmd | getline                                                #bjp999 
  other_reads[theDevIndex] = $1                                #bjp999 
  other_writes[theDevIndex] = $5                               #bjp999 
  close(cmd)                                                   #bjp999 
}                                                              #bjp999 
