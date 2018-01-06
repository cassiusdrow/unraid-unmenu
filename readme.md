
# unraid-unmenu

Loaded from the [Google Code website repository](https://code.google.com/archive/p/unraid-unmenu/)

[[Downloads]](./downloads)   [[Source archives]](./archives)

## unraid-unmenu

*An improved, extensible web-interface to Lime-Technology's unRAID NAS*

Unmenu is an improved, extensible web interface to supplement the web-based management console on Lime-Technology's unRAID Network Attached Storage OS.

Unmenu is a web-server and a set of web-pages written in GNU Awk. It is restricted in that it can only handle one "request" connection at a time. Plug-in pages can be written in "awk" or in any interpreted text language.

To install this on an unRAID server create a **/boot/unmenu** directory

**mkdir /boot/unmenu**

Download the unmenu_install zip file. **The install utility will download the latest version of unMENU.** (It does not have the same version number as unMENU)

Unzip and move unmenu_install to the **/boot/unmenu** directory.

Then
**cd /boot/unmenu**
**unmenu_install -i -d /boot/unmenu**

If you already have an older unmenu version installed type
**unmenu_install -u**

To check an existing installation for available updates, type
**unmenu_install -c**

To start unmenu running, invoke it as
**/boot/unmenu/uu**
or
**cd /boot/unmenu**
**./uu**

Once running you can view the unMENU pages in your web-browser by browsing to
**//tower:8080**

If you had a prior version of unMENU running, you'll need to restart it to see the new version.
This will typically do it:
**killall awk**
**/boot/unmenu/uu**

If you are running an older version of unRAID that does not have the "wget" command you will need to download and install it. (wget was added in version 4.4-final of unRAID)
Instructions are in this post on the unRAID forum:

   *http://lime-technology.com/forum/index.php?topic=6018.msg57535#msg57535*

### Project Information

 - License: [GNU GPL v2](http://www.gnu.org/licenses/old-licenses/gpl-2.0.html)
 - 25 stars
 - svn-based source control

Labels: [[unraid]](https://code.google.com/archive/search?q=domain:code.google.com%20label:unraid)  [[unmenu]](https://code.google.com/archive/search?q=domain:code.google.com%20label:unmenu)  [[web-server]](https://code.google.com/archive/search?q=domain:code.google.com%20label:web-server)  [[awk]](https://code.google.com/archive/search?q=domain:code.google.com%20label:awk)  [[lime-technology]](https://code.google.com/archive/search?q=domain:code.google.com%20label:lime-technology)  [[unmenuisaweb-server]](https://code.google.com/archive/search?q=domain:code.google.com%20label:unmenuisaweb-server)







