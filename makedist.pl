#!/usr/local/bin/perl
# Builds a tar.gz package of a specified Webmin version

if ($0 =~ /^(.*)\//) {
	chdir($1);
	}
@ARGV == 1 || @ARGV == 2 || usage();
if ($ARGV[0] eq "-minimal" || $ARGV[0] eq "--minimal") {
	$min++;
	shift(@ARGV);
	}
$fullvers = $ARGV[0];
$fullvers =~ /^([0-9\.]+)(\-(\d+))?$/ || usage();
$vers = $1;
$release = $3;
$tardir = $min ? "minimal" : "tarballs";
$vfile = $min ? "$fullvers-minimal" : $fullvers;
$zipdir = "zips";
$vers || usage();

@files = ("config.cgi", "config-*-linux",
	  "config-solaris", "images", "index.cgi", "mime.types",
	  "miniserv.pl", "os_list.txt", "perlpath.pl", "setup.sh", "setup.pl", "setup.bat",
	  "version", "web-lib.pl", "web-lib-funcs.pl",
	  "config_save.cgi", "chooser.cgi", "miniserv.pem",
	  "config-aix", "update-from-repo.sh", "README.md",
	  "newmods.pl", "copyconfig.pl", "config-hpux", "config-freebsd",
	  "changepass.pl", "help.cgi", "user_chooser.cgi",
	  "group_chooser.cgi", "config-irix", "config-osf1", "thirdparty.pl",
	  "oschooser.pl", "config-unixware",
	  "config-openserver", "switch_user.cgi", "lang", "lang_list.txt",
	  "webmin-init", "webmin-daemon",
	  "config-openbsd",
	  "config-macos", "LICENCE",
	  "session_login.cgi", "acl_security.pl",
	  "defaultacl", "rpc.cgi", "date_chooser.cgi", "switch_skill.cgi",
	  "safeacl", "install-module.pl", "LICENCE.ja", 
	  "favicon.ico", "config-netbsd", "fastrpc.cgi",
	  "defaulttheme", "feedback.cgi", "feedback_form.cgi",
	  "javascript-lib.pl", "webmin-pam", "webmin-debian-pam", "maketemp.pl",
	  "run-uninstalls.pl",
	  "webmin-gentoo-init", "run-postinstalls.pl",
	  "config-lib.pl", "entities_map.txt", "ui-lib.pl",
	  "password_form.cgi", "password_change.cgi", "pam_login.cgi",
	  "module_chooser.cgi", "config-windows", "xmlrpc.cgi",
	  "uptracker.cgi", "create-module.pl", "webmin_search.cgi",
	  "webmin-search-lib.pl", "WebminCore.pm",
	  "record-login.pl", "record-logout.pl", "record-failed.pl",
	  "robots.txt", "unauthenticated", "bin",
	 );
if ($min) {
	# Only those required by others
	@mlist = ("cron", "init", "inittab", "proc", "webmin", "acl", "servers",
		  "man", "webminlog", "system-status", "webmincron");
	}
else {
	# All the modules
	my $mod_def_list;
	my $curr_dir = $0;
	($curr_dir) = $curr_dir =~ /^(.+)\/[^\/]+$/;
	$curr_dir = "." if ($curr_dir !~ /^\//);
	open(my $fh, '<', "$curr_dir/mod_def_list.txt") || die "Error opening \"mod_def_list.txt\" : $!\n";
	$mod_def_list = do { local $/; <$fh> };
	close($fh);
	@mlist = split(/\s+/, $mod_def_list);
	}
@dirlist = ( "WebminUI", "JSON" );

$dir = "webmin-$vers";
if (!$release || !-d "$tardir/$dir") {
	# Copy files into the directory for tarring up, unless this is a minor
	# release or a new version
	system("rm -rf $tardir/$dir");
	mkdir("$tardir/$dir", 0755);

	# Copy top-level files to directory
	print "Adding top-level files\n";
	$flist = join(" ", @files);
	system("cp -r -L $flist $tardir/$dir");
	system("touch $tardir/$dir/install-type");
	system("echo $vers > $tardir/$dir/version");
	if ($min) {
		system("touch $tardir/$dir/minimal-install");
		}

	# Add module files
	foreach $m (@mlist) {
		print "Adding module $m\n";
		mkdir("$tardir/$dir/$m", 0755);
		$flist = "";
		opendir(DIR, $m);
		foreach $f (readdir(DIR)) {
			next if ($f =~ /^\./ || $f =~ /\.git$/ ||
				 $f =~ /\.(tar|wbm|wbt)\.gz$/ ||
				 $f eq "README.md" || $f =~ /^makemodule.*\.pl$/ ||
				 $f eq "linux.sh" || $f eq "freebsd.sh" || 
				 $f eq "LICENCE" || $f eq "version");
			$flist .= " $m/$f";
			}
		closedir(DIR);
		system("cp -r -L $flist $tardir/$dir/$m");
		}

	# Remove files that shouldn't be publicly available
	system("rm -rf $tardir/$dir/status/mailserver*");
	system("rm -rf $tardir/$dir/file/plugin.jar");
	system("rm -rf $tardir/$dir/authentic-theme/update");

	# Clear out minified JS
	if (-d "$tardir/$dir/authentic-theme/extensions") {
		system("cat /dev/null >$tardir/$dir/authentic-theme/extensions/csf.min.js");
		}

	# Remove theme settings files
	if (-d "$tardir/$dir/authentic-theme") {
		system("find $tardir/$dir/authentic-theme -name 'settings_*.js' | xargs rm");
		}

	# Add other directories
	foreach $d (@dirlist) {
		print "Adding directory $d\n";
		system("cp -r $d $tardir/$dir");
		}

	# Update module.info and theme.info files with depends and version
	opendir(DIR, "$tardir/$dir");
	while($d = readdir(DIR)) {
		# set depends in module.info to this version
		next if ($d eq "authentic-theme");	# Theme version matters
		local $minfo = "$tardir/$dir/$d/module.info";
		local $tinfo = "$tardir/$dir/$d/theme.info";
		if (-r $minfo) {
			local %minfo;
			&read_file($minfo, \%minfo);
			$minfo{'depends'} = join(" ", split(/\s+/, $minfo{'depends'}),
						      $vers);
			$minfo{'version'} = $vers;
			&write_file($minfo, \%minfo);
			}
		elsif (-r $tinfo) {
			local %tinfo;
			&read_file($tinfo, \%tinfo);
			$tinfo{'depends'} = join(" ", split(/\s+/, $tinfo{'depends'}),
						      $vers);
			$tinfo{'version'} = $vers;
			&write_file($tinfo, \%tinfo);
			}
		}
	closedir(DIR);

	# Make blue-theme a symlink instead of a copy
	if (!$min && -r "$tardir/$dir/gray-theme") {
		system("cd $tardir/$dir && ln -s gray-theme blue-theme");
		}
	}

# Store release version, if set
if ($release) {
	system("echo $release > $tardir/$dir/release");
	}
else {
	unlink("$tardir/$dir/release");
	}

# Create the tar.gz file
print "Creating webmin-$vfile.tar.gz\n";
system("cd $tardir ; tar cvf - $dir 2>/dev/null | gzip -c >webmin-$vfile.tar.gz");

if (!$min && -d $zipdir) {
	# Create a .zip file too
	print "Creating webmin-$vfile.zip\n";
	system("rm -rf $zipdir/webmin");
	system("mkdir $zipdir/webmin");
	system("cp -rp $tardir/$dir/* $zipdir/webmin");
	system("rm -rf $zipdir/webmin/{fdisk,exports,bsdexports,hpuxexports,sgiexports,zones,rbac,Webmin}");
	system("rm -rf $zipdir/webmin/acl/Authen-SolarisRBAC-0.1/*");
	system("echo zip >$zipdir/webmin/install-type");
	open(FIND, "find $zipdir/webmin -name '*\\**' |");
	while(<FIND>) {
		s/\n//g;
		$orig = $_;
		($nw = $orig) =~ s/\*/ALL/g;
		if ($nw ne $orig) {
			rename($orig, $nw);
			}
		}
	close(FIND);
	unlink("$zipdir/webmin-$vfile.zip");
	system("cd $zipdir && zip -r webmin-$vfile.zip webmin >/dev/null 2>&1");
	}

if (!$min && -d "modules") {
	# Create per-module .wbm files
	print "Creating modules\n";
	opendir(DIR, "$tardir/$dir");
	while($d = readdir(DIR)) {
		# create the module.wbm file
		local $minfo = "$tardir/$dir/$d/module.info";
		next if (!-r $minfo);
		unlink("modules/$d.wbm", "modules/$d.wbm.gz");
		system("(cd $tardir/$dir ; tar chf - $d | gzip -c) >modules/$d.wbm.gz");
		}
	closedir(DIR);
	}

# Create the signature file
if (-d "sigs") {
	unlink("sigs/webmin-$vfile.tar.gz-sig.asc");
	system("gpg --armor --output sigs/webmin-$vfile.tar.gz-sig.asc --default-key jcameron\@webmin.com --detach-sig $tardir/webmin-$vfile.tar.gz");
	}

# Create a change log for this version
if (-d "/home/jcameron/webmin.com" && !$release) {
	$lastvers = sprintf("%.2f0", $vers - 0.005);	# round down to last stable
	if ($lastvers == $vers) {
		# this is a new full version, so round down to the previous full version
		$lastvers = sprintf("%.2f0", $vers-0.006);
		}
	system("./showchangelog.pl --html $lastvers >/home/jcameron/webmin.com/changes-$vers.html");
	}

if ($min && !$release) {
	# Delete the tarball directory
	system("rm -rf $tardir/$dir");
	}

# read_file(file, &assoc, [&order])
# Fill an associative array with name=value pairs from a file
sub read_file
{
open(ARFILE, $_[0]) || return 0;
while(<ARFILE>) {
        chop;
        if (!/^#/ && /^([^=]+)=(.*)$/) {
		$_[1]->{$1} = $2;
		push(@{$_[2]}, $1);
        	}
        }
close(ARFILE);
return 1;
}
 
# write_file(file, array)
# Write out the contents of an associative array as name=value lines
sub write_file
{
local($arr);
$arr = $_[1];
open(ARFILE, "> $_[0]");
foreach $k (keys %$arr) {
        print ARFILE "$k=$$arr{$k}\n";
        }
close(ARFILE);
}

sub usage
{
die "usage: makedist.pl [-minimal] <version>";
}

