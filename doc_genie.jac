node documentation {
    has title;
    has content;
    has output_path;
    has generated_at;
    has repository_url;
}

walker generate_final_docs {
    has repo_data;
    has code_graph;
    has output_path;
    has github_url;
    has final_output_path;
    
    can utils.generate_markdown_document;
    can utils.create_relationship_diagram;
    
    with entry {
        std.out("📝 DocGenie: Starting documentation generation...");
        std.out("📊 Repository data: " + std.length(repo_data) + " items");
        std.out("📊 Code graph: " + std.length(code_graph) + " modules");
        
        // Generate markdown documentation
        spawn here walker::utils.generate_markdown_document(
            repo_data=repo_data,
            code_graph=code_graph,
            output_path=output_path,
            github_url=github_url
        );
    }
    
    markdown_generated {
        std.out("✅ DocGenie: Markdown documentation generated");
        std.out("📄 Output file: " + visitor.output_file);
        
        // Create relationship diagrams
        spawn here walker::utils.create_relationship_diagram(
            code_graph=code_graph,
            output_path=visitor.output_dir
        );
    }
    
    diagrams_created {
        std.out("✅ DocGenie: Diagrams created");
        
        // Read the generated documentation
        doc_content = std.file_load(visitor.output_file);
        
        // Create documentation node
        spawn here --> node::documentation(
            title=repo_data.file_tree.name + " Documentation",
            content=doc_content,
            output_path=visitor.output_file,
            generated_at=std.time_now(),
            repository_url=github_url
        );
        
        // Signal completion to supervisor
        take --> node::supervisor;
        here::docs_generation_completed(
            final_output_path=visitor.output_file
        );
    }
}