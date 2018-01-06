
"Original-Google-Code-Archive" branch loaded from the [Google Code website repository](https://code.google.com/archive/p/unraid-unmenu/)

"master" branch has further changes not made by the original author.

# unraid-unmenu

   *An improved, extensible web-interface to Lime-Technology's unRAID NAS*

Unmenu is an improved, extensible web interface to supplement the web-based management console on Lime-Technology's unRAID Network Attached Storage OS.

Unmenu is a web-server and a set of web-pages written in GNU Awk. It is restricted in that it can only handle one "request" connection at a time. Plug-in pages can be written in "awk" or in any interpreted text language.

To install this on an unRAID server create a **/boot/unmenu** directory

```bash
mkdir /boot/unmenu
```

Download the unmenu_install zip file. **The install utility will download the latest version of unMENU.** (It does not have the same version number as unMENU.)

**\*\*NOTE: The install utility no longer works properly due to code freeze in Google Code and the move to github.\*\***

Unzip and move unmenu_install to the **/boot/unmenu** directory.

Then

```bash
cd /boot/unmenu
unmenu_install -i -d /boot/unmenu
```

If you already have an older unmenu version installed type

```bash
unmenu_install -u
```

To check an existing installation for available updates, type

```bash
unmenu_install -c
```

To start unmenu running, invoke it as

```bash
/boot/unmenu/uu
```

or

```bash
cd /boot/unmenu
./uu
```

Once running you can view the unMENU pages in your web-browser by browsing to

```
//tower:8080
```

If you had a prior version of unMENU running, you'll need to restart it to see the new version.
This will typically do it:

```bash
killall awk
/boot/unmenu/uu
```

If you are running an older version of unRAID that does not have the "wget" command you will need to download and install it. (wget was added in version 4.4-final of unRAID)
Instructions are in this post on the unRAID forum:

   https://lime-technology.com/forums/topic/5813-unmenu-installation-problem/?tab=comments#comment-56736

## Useful unRAID forum threads

   [An improved, extensible web-interface to Lime-Technology's unRAID NAS](https://lime-technology.com/forums/topic/2521-an-improved-unraid-web-interface-extensible-and-easy-to-install/)

   [unMENU 1.6 - now available (A major upgrade in appearance)](https://lime-technology.com/forums/topic/25692-unmenu-16-now-available-a-major-upgrade-in-appearance/)

   [myMain 1.5 - Now Integrated into unmenu](https://lime-technology.com/forums/topic/8765-mymain-15-now-integrated-into-unmenu/)

   [myMain Support and Information Thread](https://lime-technology.com/forums/topic/31237-mymain-support-and-information-thread/)

   [New unmenu pluging: myMain](https://lime-technology.com/forums/topic/2628-new-unmenu-pluging-mymain/)

## Project Information

 - License: [GNU GPL v2](http://www.gnu.org/licenses/old-licenses/gpl-2.0.html)
 - 25 stars
 - svn-based source control

Labels: [[unraid]](https://code.google.com/archive/search?q=domain:code.google.com%20label:unraid)  [[unmenu]](https://code.google.com/archive/search?q=domain:code.google.com%20label:unmenu)  [[web-server]](https://code.google.com/archive/search?q=domain:code.google.com%20label:web-server)  [[awk]](https://code.google.com/archive/search?q=domain:code.google.com%20label:awk)  [[lime-technology]](https://code.google.com/archive/search?q=domain:code.google.com%20label:lime-technology)  [[unmenuisaweb-server]](https://code.google.com/archive/search?q=domain:code.google.com%20label:unmenuisaweb-server)

## [Downloads](./downloads/)

**File** | **Summary** | **Labels** | **Uploaded** | **Size**
-------- | ----------- | ---------- | ------------ | --------
[unmenu_install1371.zip](./downloads/unmenu_install1371.zip) | unMENU install/update utility. It will install the latest version of unMENU | Featured Type-Archive | Dec 4, 2010 | 3.77KB
[unmenu_install137.zip](./downloads/unmenu_install137.zip) | unMENU install/update utility version 1.3.7 | Deprecated  Type-Archive | Dec 2, 2010 | 3.67KB
[unmenu_install136.zip](./downloads/unmenu_install136.zip) | unMENU 1.3.6 install/update utility | Deprecated  Type-Archive  OpSys-Linux | Sep 5, 2010 | 3.54KB
[unmenu_install135.zip](./downloads/unmenu_install135.zip) | unMENU 1.3.5 update/install utility | Deprecated  Type-Archive  OpSys-Linux | May 16, 2010 | 3.08KB
[unmenu_install134.zip](./downloads/unmenu_install134.zip) | unMENU 1.3.4 update/install utility | Deprecated  Type-Archive  OpSys-Linux | May 1, 2010 | 3.06KB
[unmenu_install133.zip](./downloads/unmenu_install133.zip) | unMENU 1.3.3 update/install utility | Deprecated  Type-Archive  OpSys-Linux | Apr 23, 2010 | 2.74KB
[unmenu_install132.zip](./downloads/unmenu_install132.zip) | unMENU 1.3.2 update/install utility | Deprecated  Type-Archive  OpSys-Linux | Apr 6, 2010 | 2.54KB
[unmenu_install131.zip](./downloads/unmenu_install131.zip) | unMENU 3.1.3 update/install utility | Deprecated  Type-Archive  OpSys-Linux | Apr 6, 2010 | 2.5KB
[unmenu_install13.zip](./downloads/unmenu_install13.zip) | unMENU 1.3 install/update utility | Deprecated  Type-Archive  OpSys-Linux | Apr 3, 2010 | 2.43KB
[unmenu_plug-ins-1-2.zip](./downloads/unmenu_plug-ins-1-2.zip) | unMENU plug-ins version 1.2 | Deprecated  Type-Archive | Sep 22, 2009 | 82.25KB
[unmenu-1-2.zip](./downloads/unmenu-1-2.zip) | unMENU improved interface version 1.2 | Deprecated  Type-Archive | Sep 22, 2009 | 23.46KB
[unMENU-packagesSept-2009.zip](./downloads/unMENU-packagesSept-2009.zip) | Updated package configuration files as of Sept. 2009 | Deprecated | Sep 22, 2009 | 12.36KB
[unmenu_package_conf-1-1.zip](./downloads/unmenu_package_conf-1-1.zip) | unmenu-1-1 package configuration files for unRAID Improved Management Interface. A web-server and plug-in system in "gawk" | Deprecated  Type-Archive | Dec 21, 2008 | 6.41KB
[unmenu_plug-ins-1-1.zip](./downloads/unmenu_plug-ins-1-1.zip) | unmenu-1-1 plug-in files for unRAID Improved Management Interface. A web-server and plug-in system in "gawk" | Deprecated  Type-Archive | Dec 21, 2008 | 60.34KB
[unmenu-1-1.zip](./downloads/unmenu-1-1.zip) | unmenu-1-1 main files for unRAID Improved Management Interface. A web-server and plug-in system in "gawk" | Deprecated  Type-Archive | Dec 21, 2008 | 23.04KB

## [Source Archive](./archive/)

**File** | **Summary**
-------- | -----------
[unraid-unmenu-svn.7z](./archive/unraid-unmenu-svn.7z) | Google Code svn archive
[unraid-unmenu-master.7z](./archive/unraid-unmenu-master.7z) | Final master branch from svn
[unraid-unmenu-git.7z](./archive/unraid-unmenu-git.7z) | Google Code svn converted to git

