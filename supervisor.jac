node supervisor {
    has name;
    has github_url;
    has output_path;
    has analysis_plan;
    has current_status = "initialized";
    has documentation_result;
}

walker supervise_workflow {
    has github_url;
    has output_path;
    
    can repo_mapper.clone_and_map_repo;
    can code_analyzer.analyze_codebase;
    can doc_genie.generate_final_docs;
    
    with entry {
        // Create supervisor node
        spawn here --> node::supervisor(
            name="code_genius",
            github_url=github_url,
            output_path=output_path
        );
        
        std.out("👨‍💼 Supervisor: Starting workflow for " + github_url);
        here.current_status = "repository_mapping";
        
        // Step 1: Repository Mapping
        std.out("📁 Supervisor: Starting repository mapping...");
        spawn here walker::clone_and_map_repo(
            github_url=github_url
        );
    }
    
    repo_mapping_completed {
        std.out("✅ Supervisor: Repository mapping completed");
        here.current_status = "code_analysis";
        
        // Step 2: Code Analysis
        std.out("🔍 Supervisor: Starting code analysis...");
        spawn here walker::analyze_codebase(
            repo_path=visitor.repo_path,
            output_path=output_path,
            repo_data=visitor.repo_data
        );
    }
    
    code_analysis_completed {
        std.out("✅ Supervisor: Code analysis completed");
        here.current_status = "documentation_generation";
        
        // Step 3: Documentation Generation
        std.out("📝 Supervisor: Starting documentation generation...");
        spawn here walker::generate_final_docs(
            repo_data=visitor.repo_data,
            code_graph=visitor.code_graph,
            output_path=output_path,
            github_url=github_url
        );
    }
    
    docs_generation_completed {
        std.out("🎉 Supervisor: Documentation generation completed!");
        std.out("💾 Output saved to: " + visitor.final_output_path);
        here.current_status = "completed";
        here.documentation_result = visitor.final_output_path;
        
        report {
            "status": "success",
            "output_path": visitor.final_output_path,
            "repository": github_url,
            "message": "Documentation generated successfully",
            "supervisor_status": here.current_status
        };
    }
}