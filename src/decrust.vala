/*
 * This file is part of the decrust distribution
 * Copyright (c) 2018 Sébastien Le Callonnec.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

class File {
    public string name;
    public string path;
    public string hash;
    public int64 size;
    public File next;
    public bool hasDuplicates = false;
}

class FileTree {
    public File file;
    public FileTree left;
    public FileTree right;
}

class Application {

    private void addToTree(File f, FileTree fileTree) {
        if (fileTree.file == null) {
            fileTree.file = f;
        }

        else if (f.size > fileTree.file.size) {
            if (fileTree.right == null) {
                fileTree.right = new FileTree();
            }
            addToTree(f, fileTree.right);
        } else if (f.size < fileTree.file.size) {
            if (fileTree.left == null) {
                fileTree.left = new FileTree();
            }
            addToTree(f, fileTree.left);
        } else {
            // Same size, need to compare hash
            if (fileTree.file.hash == null) {
                fileTree.file.hash = computeHash(fileTree.file.path);
            }
            f.hash = computeHash(f.path);
            if (f.hash > fileTree.file.hash) {
                if (fileTree.right == null) {
                    fileTree.right = new FileTree();
                }
                addToTree(f, fileTree.right);
            } else if (f.hash < fileTree.file.hash) {
                if (fileTree.left == null) {
                    fileTree.left = new FileTree();
                }
                addToTree(f, fileTree.left);
            } else {
                // Same hash, we found a duplicate.
                var existingFile = fileTree.file;
                File tmp = existingFile.next;
                f.next = tmp;
                existingFile.hasDuplicates = true;
                existingFile.next = f;
            }
        }
    }

    private string computeHash(string path) {
        try {
            uint8[] file_contents;
            FileUtils.get_data(path, out file_contents);
            string digest = GLib.Checksum.compute_for_data(ChecksumType.MD5, file_contents);
            return digest;
        } catch (GLib.Error err) {
            stderr.printf(err.message);
        }
        return "";
    }

    public int walkDir(string dir, FileTree fileTree) {
        int fileCount = 0;
        try {
            var d = Dir.open(dir);
            string? name = null;
            while ((name = d.read_name()) != null) {
                string path = Path.build_filename(dir, name);
                if (FileUtils.test(path, FileTest.IS_REGULAR)) {
                    File f = new File();
                    f.name = name;
                    f.path = path;

                    var file = GLib.File.new_for_path(path);
                    var file_info = file.query_info(FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);
                    f.size = file_info.get_size();

                    addToTree(f, fileTree);

                    fileCount++;
                } else if (FileUtils.test(path, FileTest.IS_DIR)) {
                    fileCount += walkDir(path, fileTree);
                }
            }
        } catch (FileError err) {
            stderr.printf(err.message);
        } catch (GLib.Error err) {
            stderr.printf(err.message);
        }

        return fileCount;
    }

    public void printDupes(FileTree fileTree) {
        if (fileTree == null) {
            return;
        }
        if (fileTree.file.hasDuplicates) {
            stdout.printf("%s\n", fileTree.file.path);
            File n = fileTree.file;
            while ((n = n.next) != null) {
                stdout.printf("%s\n", n.path);
            }
            stdout.printf("\n");
        }

        if (fileTree.left != null) printDupes(fileTree.left);
        if (fileTree.right != null) printDupes(fileTree.right);

    }
}

public static int main(string[] args) {
    var application = new Application();
    var fileTree = new FileTree();
    int fileCount = application.walkDir(".", fileTree);
    stdout.printf("File count: %d\n\n", fileCount);
    application.printDupes(fileTree);

    return 0;
}

// Local Variables:
// mode: vala
// eval: (setq indent-tabs-mode nil)
// End:
