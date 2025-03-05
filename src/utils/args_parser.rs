pub struct ArgsParser;

impl ArgsParser {
    /// 解析参数，将非 `-` 开头的参数归入 `packages`，其余归入 `manager_args`
    pub fn parse(args: &[String]) -> (Vec<String>, Vec<String>) {
        let mut packages = Vec::new();
        let mut manager_args = Vec::new();
        let mut found_flag = false;

        for arg in args {
            if !found_flag && !arg.starts_with('-') {
                packages.push(arg.clone());
            } else {
                found_flag = true;
                manager_args.push(arg.clone());
            }
        }

        (packages, manager_args)
    }
}
