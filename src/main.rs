/*
 * This file is part of the decrust distribution
 * Copyright (c) 2019  Sébastien Le Callonnec.
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
use std::fs;
use std::path::{Path, PathBuf};
use std::boxed::Box;
use std::io;
use sha2::{Sha256, Digest};

pub struct File {
    pub name: String,
    pub path: PathBuf,
    pub hash: Option<Vec<u8>>,
    pub size: u64,
    pub next: Option<Box<File>>,
    pub has_dupes: bool
}

impl File {
    fn compute_hash(&mut self) {
        let mut hasher = Sha256::new();
        let mut file = match std::fs::File::open(&self.path.as_path()) {
            Err(e) => panic!("couldn't open file: {}", e),
            Ok(file) => file
        };
        io::copy(&mut file, &mut hasher).unwrap();
        self.hash = Some(hasher.result().as_slice().to_vec());
    }
}

pub struct FileTree {
    pub file: Option<Box<File>>,
    pub left: Option<Box<FileTree>>,
    pub right: Option<Box<FileTree>>
}

impl FileTree {
    fn new() -> FileTree {
        FileTree {
            file: None,
            left: None,
            right: None
        }
    }

    fn add_to_tree(&mut self, mut f:File) {
        match &mut self.file {
            None => self.file = Some(Box::new(f)),
            Some(file) => if f.size > file.size {
                match self.right {
                    None => self.right = Some(Box::new(FileTree::new())),
                    Some(_) => {}//
                }

                match self.right {
                    Some(ref mut l) => l.add_to_tree(f),
                    None => {}
                }
            } else if f.size < file.size {
                match self.left {
                    None => self.left = Some(Box::new(FileTree::new())),
                    Some(_) => {}
                }

                match self.left {
                    Some(ref mut l) => l.add_to_tree(f),
                    None => {}
                }
            } else {
                // same size, need to compare hash
                match self.file {
                    Some(ref mut ff) => {
                        match ff.hash {
                            None => ff.compute_hash(),
                            _ => {}
                        }

                        f.compute_hash();

                        if f.hash > ff.hash {
                            match self.right {
                                None => self.right = Some(Box::new(FileTree::new())),
                                Some(_) => {}//
                            }
                            match self.right {
                                Some(ref mut l) => l.add_to_tree(f),
                                None => {}
                            }
                        } else if f.hash < ff.hash {
                            match self.left {
                                None => self.left = Some(Box::new(FileTree::new())),
                                Some(_) => {}//
                            }
                            match self.left {
                                Some(ref mut l) => l.add_to_tree(f),
                                None => {}
                            }
                        } else {
                            // same hash we found a dupes
                            f.next = Some(Box::new(*ff));
                            ff.has_dupes = true;
                            ff.next = Some(Box::new(f));
                        }
                    },
                    None => panic!("Should find a file here")
                }
            }
        }
    }
}

pub fn walk_dir(path: &Path, file_tree: &mut FileTree) -> u16 {
    let mut count:u16 = 0;

    let paths = fs::read_dir(path).unwrap();
    for p in paths {
        if let Ok(p) = p {
            let p = p.path();
            if p.is_file() {
                let file:File = File {
                    name: String::from(p.file_name().unwrap().to_str().unwrap()),
                    path: p.canonicalize().unwrap(),
                    size: p.metadata().unwrap().len(),
                    has_dupes: false,
                    hash: None,
                    next: None
                };
                file_tree.add_to_tree(file);
                count = count + 1;
            } else if p.is_dir() {
                count = count + walk_dir(&p, file_tree);
            }
        }
    }

    return count;
}


fn main() {
    let path = Path::new(".");
    let mut tree = FileTree::new();

    let count = walk_dir(&path, &mut tree);
    println!("Found {} files.", count);
}
