node code_module {
    has name;
    has module_type;  // "function", "class", "module", "walker", "node"
    has file_path;
    has source_code;
    has line_number;
    has dependencies = [];
    has called_by = [];
}

edge calls {
    has relationship = "calls";
}

edge imports {
    has relationship = "imports";
}

edge inherits {
    has relationship = "inherits";
}

walker analyze_codebase {
    has repo_path;
    has output_path;
    has repo_data;
    has code_graph = {};
    has python_modules = [];
    has jac_modules = [];
    
    can utils.parse_python_files;
    can utils.parse_jac_files;
    can utils.build_relationship_graph;
    
    with entry {
        std.out("🔍 Code Analyzer: Starting code analysis...");
        std.out("📁 Analyzing repository: " + repo_path);
        
        // Parse Python files
        spawn here walker::utils.parse_python_files(
            repo_path=repo_path
        );
    }
    
    python_parsed {
        std.out("✅ Code Analyzer: Python files parsed");
        std.out("📊 Python modules found: " + std.length(visitor.python_modules));
        
        // Parse Jac files
        spawn here walker::utils.parse_jac_files(
            repo_path=repo_path
        );
    }
    
    jac_parsed {
        std.out("✅ Code Analyzer: Jac files parsed");
        std.out("📊 Jac modules found: " + std.length(visitor.jac_modules));
        
        // Build relationship graph
        spawn here walker::utils.build_relationship_graph(
            python_modules=visitor.python_modules,
            jac_modules=visitor.jac_modules
        );
    }
    
    graph_built {
        std.out("✅ Code Analyzer: Relationship graph built");
        
        // Create code graph nodes
        modules_count = 0;
        for module in visitor.all_modules {
            spawn here --> node::code_module(
                name=module.name,
                module_type=module.type,
                file_path=module.file_path,
                source_code=module.source_code[:500] + "..." if std.length(module.source_code) > 500 else module.source_code,
                line_number=module.line_number,
                dependencies=module.dependencies
            );
            modules_count += 1;
        }
        
        std.out("📊 Total code modules created: " + modules_count);
        
        // Signal completion to supervisor
        take --> node::supervisor;
        here::code_analysis_completed(
            code_graph={
                "python_modules": visitor.python_modules,
                "jac_modules": visitor.jac_modules,
                "relationships": visitor.relationships,
                "total_modules": modules_count
            }
        );
    }
}