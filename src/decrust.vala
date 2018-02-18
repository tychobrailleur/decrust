class File {
	public string name;
	public string hash;
	public int64 size;
	public File next;
	public File duplicates;
	public bool hasDuplicates = false;
}

class FileTree {
	public File file;
	public FileTree left;
	public FileTree right;
}

class Application {

	public void addToTree(File f, FileTree fileTree) {
		if (f.hash > fileTree.file.hash) {
			stdout.printf("Right...");
			if (fileTree.right == null) {
				fileTree.right = new FileTree();
			}
			addToTree(f, fileTree.right);
		} else if (f.hash < fileTree.file.hash) {
			stdout.printf("Left...");
			if (fileTree.left == null) {
				fileTree.left = new FileTree();
			}
			addToTree(f, fileTree.left);
		} else {
			stdout.printf("Same!");
			if (fileTree.file == null) {
				fileTree.file = f;
			} else {
				var existingFile = fileTree.file;
				f.next = existingFile;
				existingFile.hasDuplicates = true;
				existingFile.duplicates = f;
			}
		}

	}

	public int grokDir(string dir, FileTree fileTree) {
		int fileCount = 0;
		try {
			var d = Dir.open(dir);
			string? name = null;
			while ((name = d.read_name ()) != null) {
				string path = Path.build_filename (dir, name);
				if (FileUtils.test (path, FileTest.IS_REGULAR)) {
					File f = new File();

					string file_contents;
					FileUtils.get_contents(path, out file_contents);
					string digest = GLib.Checksum.compute_for_string(ChecksumType.SHA1, file_contents, file_contents.length);
					f.hash = digest;

					stdout.printf("File: %lld\n" , f.size);
					stdout.printf("   md5: %s\n" , f.hash);

					if (fileTree.file == null) {
						fileTree.file = f;
					} else {
						addToTree(f, fileTree);
					}

					fileCount++;
				} else if (FileUtils.test (path, FileTest.IS_DIR)) {
					fileCount += grokDir(path, fileTree);
				}
			}
		} catch (FileError err) {
			stderr.printf("err.message");
		} catch (GLib.Error err) {
			stderr.printf("err.message");
		}

		return fileCount;
	}
}

int main(string args[]) {
	var application = new Application();
	var fileTree = new FileTree();
	int fileCount = application.grokDir(".", fileTree);
	stdout.printf("File count: %d\n", fileCount);
	return 0;
}
