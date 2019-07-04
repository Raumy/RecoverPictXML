/* **************************************************************************
                                                                       *
*  Copyright (C) 2000, 2004 by Cyriac REMY (aka Raum, raum@forward.to)    *
*  All Rights Reserved.                                                   *
*************************************************************************** */

// valac --pkg gtk+-3.0 recover_pictures.vala
// need nircmd.exe from NirSoft

using Gtk;
using Gdk;

void save_png(string filename, ref string s) {
	var decoded_buffer = Base64.decode(s);

    MemoryInputStream mis = new MemoryInputStream.from_bytes(new Bytes(decoded_buffer));

    Pixbuf pixbuf = new Pixbuf.from_stream(mis);

    pixbuf.save(filename, "png");
}

void main(string[] args) {
	if (args.length != 2) {
		print ("%s <XML FILE>\n", args[0]);
		return;
	}

	try {
			File file = File. new_for_path  ("images");
			if (! file.query_exists())
				file.make_directory ();
		} catch (Error e) {
			print ("Error: %s\n", e.message);
		}

    var file = File.new_for_path (args[1]);

    var dis = new DataInputStream (file.read ());
    string line;
    string date = "";
	FileInfo info = null;

    // Read lines until end of file (null) is reached
    while ((line = dis.read_line (null)) != null) {

    	if (line.contains("mms text_only")) {
			string pattern = ".* date=\"(?P<date>[^\"]*).*";
        	GLib.Regex exp = new GLib.Regex (pattern);
        	GLib.MatchInfo mi;

        	if (exp.match (line, 0, out mi)) {
	            string s = mi.fetch_named ("date");
	            s = s.substring (0, s.length - 3);

				var time = new DateTime.from_unix_utc (int64.parse(s));

				time = time.add_hours(1);

				if ((time.get_month() >= 4) && (time.get_month()<= 10))
					time = time.add_hours(1);

				date = time.format ("%d-%m-%Y %H:%M:%S");
	        }
    	}

    	if (line.contains("ct=\"image/jpeg\"")) {
        	string pattern = ".*cl=\"(?P<name>[^\"]*).*data=\"(?P<data>[^\"]*).*";

        	GLib.Regex exp = new GLib.Regex (pattern);
        	GLib.MatchInfo mi;

        	if (exp.match (line, 0, out mi)) {
	            string s = mi.fetch_named ("data");
	            save_png("images/" + mi.fetch_named ("name"), ref s);

				MainLoop loop = new MainLoop ();
					try {
						// setfiletime "c:\temp\myfile.txt" "24-06-2003 17:57:11" "22-11-2005 10:21:56"
						string[] spawn_args = {"nircmd.exe", "setfiletime", "images\\" + mi.fetch_named ("name"), date, date};
						string[] spawn_env = Environ.get ();
						Pid child_pid;

						Process.spawn_async (null,
							spawn_args,
							spawn_env,
							SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
							null,
							out child_pid);

						ChildWatch.add (child_pid, (pid, status) => {
							// Triggered when the child indicated by child_pid exits
							Process.close_pid (pid);
							loop.quit ();
						});

						loop.run ();
					} catch (SpawnError e) {
						print ("Error: %s\n", e.message);
					}
	        }
    	}
    }
}