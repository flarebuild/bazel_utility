use std::env;
use std::fmt;
use std::{fs, fs::OpenOptions};
use std::path::Path;
use std::process::{ Command, Output };
use std::collections::BTreeMap;
use serde::{Deserialize, Serialize};

#[derive(Debug, PartialEq, Deserialize, Serialize)]
struct DepDesc {
    maybe_path: String,
    remote: String,
    commit: Option<String>,
}

type Result<T> = core::result::Result<T, Box<dyn std::error::Error>>;

#[derive(Debug)]
struct ExitCodeError(i32, String);
impl fmt::Display for ExitCodeError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{} - {}", self.0, self.1)
    }
}

impl std::error::Error for ExitCodeError {}

macro_rules! build_from_paths {
    ($base:expr, $($segment:expr),+) => {{
        let mut base: ::std::path::PathBuf = $base.into();
        $(
            base.push($segment);
        )*
        base
    }}
}

fn check_exit_code(out: &Output, print_stderr: bool) -> Result<()> {
    if !out.status.success() {
        return Err(Box::new(ExitCodeError(
            out.status.code().unwrap(),
            if print_stderr {
                String::from_utf8_lossy(&out.stderr).to_string()
            } else {
                "".to_owned()
            }
        )))
    }
    Ok(())
}

fn main() -> Result<()> {
    let args: Vec<String> = env::args().collect();
    let config = &args[1];
    let workspace_dir = env::var("BUILD_WORKSPACE_DIRECTORY")?;
    let config_path_str = format!("{}/{}", workspace_dir, config);
    let config_path = Path::new(&config_path_str);

    let config_file = OpenOptions::new()
        .read(true)
        .write(true)
        .open(config_path)?;

    let data: BTreeMap<String, DepDesc> = serde_yaml::from_reader(config_file)?;
    let mut new_data =  BTreeMap::<String, DepDesc>::new();

    let base_dir = config_path.parent().unwrap();
    for (dep, mut desc) in data.into_iter() {
        let mut dir_path = build_from_paths!(base_dir, &desc.maybe_path);
        println!("Checking {}", dir_path.display().to_string());
        if !dir_path.exists() {
            println!("not exists");
            new_data.insert(dep, desc);
            continue
        }
        dir_path = dir_path.canonicalize()?;

        let dir = dir_path.to_str().unwrap();

        check_exit_code(&Command::new("/usr/bin/env")
            .env_clear()
            .args(&["git", "-C", &dir, "update-index", "-q", "--ignore-submodules", "--refresh",])
            .output()?, true)?;

        if !Command::new("/usr/bin/env")
            .env_clear()
            .args(&["git", "-C", &dir, "diff-files", "--quiet", "--ignore-submodules"])
            .output()?
            .status
            .success() {

            println!("linked repo \"{}\" located at {:?}, git has unstaged changes.", &dep, dir);
            println!("{}", String::from_utf8_lossy(
                &Command::new("/usr/bin/env")
                    .env_clear()
                    .args(&["git", "-C", &dir, "diff-files", "--name-status", "-r", "--ignore-submodules"])
                    .output()?
                    .stdout));

            println!("Please commit or stash them.");
            return Err(Box::new(ExitCodeError(1, String::new())));
        }

        if !Command::new("/usr/bin/env")
            .env_clear()
            .args(&["git", "-C", &dir, "diff-index", "--cached", "--quiet", "HEAD", "--ignore-submodules"])
            .output()?
            .status
            .success() {

            println!("linked repo \"{}\" located at {:?}, git index contains uncommitted changes.", &dep, dir);
            println!("{}", String::from_utf8_lossy(
                &Command::new("/usr/bin/env")
                    .env_clear()
                    .args(&["git", "-C", &dir, "diff-index",  "--cached", "--name-status", "-r", "--ignore-submodules"])
                    .output()?
                    .stdout));

            println!("Please commit or stash them.");
            return Err(Box::new(ExitCodeError(1, String::new())));
        }

        desc.commit = Some(String::from_utf8_lossy(
            &Command::new("/usr/bin/env")
                .env_clear()
                .args(&["git", "-C", &dir, "rev-parse", "HEAD"])
                .output()?
                .stdout).trim().to_owned());

        new_data.insert(dep, desc);
    }

    let serialized = serde_yaml::to_string(&new_data)?
        .split("\n")
        .skip(1)
        .map(|x| x.to_owned())
        .collect::<Vec<String>>()
        .join("\n");

    fs::write(config_path, serialized)?;
    Ok(())
}
