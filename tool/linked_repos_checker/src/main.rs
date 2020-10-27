use std::env;
use std::{fs, fs::OpenOptions};
use std::path::Path;
use std::process::Command;
use std::collections::BTreeMap;
use serde::{Deserialize, Serialize};

#[derive(Debug, PartialEq, Deserialize, Serialize)]
struct DepDesc {
    maybe_path: String,
    remote: String,
    commit: Option<String>,
}

macro_rules! build_from_paths {
    ($base:expr, $($segment:expr),+) => {{
        let mut base: ::std::path::PathBuf = $base.into();
        $(
            base.push($segment);
        )*
        base
    }}
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();
    let last_commit_getter = Path::new(&args[1]).canonicalize()?;
    let config = &args[2];
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
        let dir_path = build_from_paths!(base_dir, &desc.maybe_path)
            .canonicalize()?;
        if !dir_path.exists() {
            new_data.insert(dep, desc);
            continue
        }

        let dir = dir_path.to_str().unwrap();
        let last_comit_res = Command::new(&last_commit_getter)
            .arg(dir)
            .output()?;

        if !last_comit_res.status.success() {
            println!("{}", String::from_utf8_lossy(&last_comit_res.stdout));
            println!("{}", String::from_utf8_lossy(&last_comit_res.stderr));
            panic!(
                "linked repo \"{}\" located at {:?} contains unstaged changes, please commit them first",
                &dep,
                dir
            )
        }

        let last_commit = String::from_utf8_lossy(&last_comit_res.stdout)
            .trim()
            .to_owned();
        desc.commit = Some(last_commit);
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
