import {*} with "./supervisor.jac";
import {*} with "./repo_mapper.jac";
import {*} with "./code_analyzer.jac";
import {*} with "./doc_genie.jac";

node system_root {
    has name = "codebase_genius_system";
}

walker init {
    root: system_root;
    
    with entry {
        spawn here --> node::system_root;
        std.out("🎯 Codebase Genius System Initialized");
        std.out("📚 Sample repository: https://github.com/Ericknzioka/generative-AI-seminar");
    }
}

// Main API walker for generating documentation
walker generate_docs {
    has github_url;
    has output_path = "./outputs";
    
    can code_genius.supervise_workflow;
    
    with entry {
        std.out("🚀 Starting documentation generation for: " + github_url);
        
        // Initialize supervisor and start workflow
        spawn here walker::supervise_workflow(
            github_url=github_url,
            output_path=output_path
        );
    }
}

// Test with Erick's generative AI seminar repo
walker test_erick_repo {
    has output_path = "./outputs";
    
    with entry {
        std.out("🧪 Testing with Erick's Generative AI Seminar Repository");
        std.out("📁 Repository: https://github.com/Ericknzioka/generative-AI-seminar");
        
        spawn here walker::generate_docs(
            github_url="https://github.com/Ericknzioka/generative-AI-seminar",
            output_path=output_path
        );
    }
}

// Quick health check walker
walker health {
    with entry {
        report {
            "status": "healthy",
            "system": "Codebase Genius",
            "version": "1.0",
            "sample_repo": "https://github.com/Ericknzioka/generative-AI-seminar",
            "timestamp": std.time_now()
        };
    }
}

// Get system info
walker info {
    with entry {
        report {
            "name": "Codebase Genius",
            "description": "AI-powered multi-agent documentation system",
            "author": "Erick Nzioka",
            "test_repository": "https://github.com/Ericknzioka/generative-AI-seminar",
            "agents": ["Supervisor", "Repo Mapper", "Code Analyzer", "DocGenie"]
        };
    }
}