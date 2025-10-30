node repository {
    has name;
    has url;
    has local_path;
    has file_tree = {};
    has readme_summary = "";
    has file_count = 0;
    has directory_count = 0;
}

node file_node {
    has name;
    has path;
    has is_directory;
    has file_type;
    has size;
    has depth;
}

walker clone_and_map_repo {
    has github_url;
    has repo_path;
    has file_tree = {};
    has readme_content;
    has readme_summary = "";
    
    can utils.clone_repository;
    can utils.generate_file_tree;
    can utils.summarize_readme;
    
    with entry {
        std.out("📥 Repo Mapper: Cloning repository...");
        
        // Clone repository using Python utility
        spawn here walker::utils.clone_repository(url=github_url);
    }
    
    clone_completed {
        std.out("✅ Repo Mapper: Repository cloned successfully");
        std.out("📁 Local path: " + visitor.cloned_path);
        
        // Generate file tree
        spawn here walker::utils.generate_file_tree(
            repo_path=visitor.cloned_path
        );
    }
    
    file_tree_generated {
        std.out("✅ Repo Mapper: File tree generated");
        std.out("📊 Files found: " + std.length(visitor.file_tree.children));
        
        // Find and summarize README
        spawn here walker::utils.summarize_readme(
            repo_path=visitor.cloned_path
        );
    }
    
    readme_summarized {
        std.out("✅ Repo Mapper: README processed");
        
        // Count files and directories
        file_count = 0;
        directory_count = 0;
        
        can count_files: with node entry {
            if (node.is_directory) {
                directory_count += 1;
                for child in node.children {
                    spawn here walker::count_files;
                }
            } else {
                file_count += 1;
            }
        }
        
        // Create repository node with all data
        repo_node = spawn here --> node::repository(
            name=std.file_base_name(github_url),
            url=github_url,
            local_path=visitor.cloned_path,
            file_tree=visitor.file_tree,
            readme_summary=visitor.readme_summary
        );
        
        // Count files
        spawn repo_node walker::count_files;
        
        // Signal completion to supervisor
        take --> node::supervisor;
        here::repo_mapping_completed(
            repo_path=visitor.cloned_path,
            repo_data={
                "file_tree": visitor.file_tree,
                "readme_summary": visitor.readme_summary,
                "file_count": file_count,
                "directory_count": directory_count
            }
        );
    }
}