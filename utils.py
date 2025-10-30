import os
import subprocess
import tempfile
import json
import ast
from pathlib import Path
import requests
import shutil

class RepositoryUtils:
    @staticmethod
    def clone_repository(github_url):
        """Clone repository to temporary directory"""
        try:
            # Create temp directory
            temp_dir = tempfile.mkdtemp(prefix="codebase_genius_")
            repo_name = github_url.split('/')[-1].replace('.git', '')
            repo_path = os.path.join(temp_dir, repo_name)
            
            print(f"🔧 Cloning {github_url} to {repo_path}")
            
            # Clone repository
            result = subprocess.run(
                ['git', 'clone', github_url, repo_path],
                capture_output=True,
                text=True,
                timeout=60
            )
            
            if result.returncode == 0:
                return {
                    "success": True,
                    "cloned_path": repo_path,
                    "temp_dir": temp_dir,
                    "repo_name": repo_name
                }
            else:
                return {
                    "success": False,
                    "error": result.stderr
                }
                
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    @staticmethod
    def generate_file_tree(repo_path):
        """Generate structured file tree"""
        def build_tree(path, depth=0):
            name = os.path.basename(path)
            
            # Skip unwanted directories
            skip_dirs = ['.git', '__pycache__', 'node_modules', '.vscode', '.idea', 'venv']
            if name in skip_dirs:
                return None
            
            item = {
                "name": name,
                "path": path,
                "is_directory": os.path.isdir(path),
                "depth": depth,
                "children": []
            }
            
            if os.path.isdir(path):
                try:
                    for child_name in sorted(os.listdir(path)):
                        child_path = os.path.join(path, child_name)
                        child_item = build_tree(child_path, depth + 1)
                        if child_item:
                            item["children"].append(child_item)
                except (PermissionError, OSError) as e:
                    item["error"] = str(e)
            else:
                item["file_type"] = Path(path).suffix
                item["size"] = os.path.getsize(path)
            
            return item
        
        root_tree = build_tree(repo_path)
        if not root_tree:
            root_tree = {"name": "empty", "is_directory": True, "children": []}
        
        return root_tree
    
    @staticmethod
    def summarize_readme(repo_path):
        """Find and summarize README file"""
        readme_files = ['README.md', 'README.rst', 'README.txt', 'README']
        
        for readme_file in readme_files:
            readme_path = os.path.join(repo_path, readme_file)
            if os.path.exists(readme_path):
                try:
                    with open(readme_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    # Simple summary (first 20 lines or 1000 characters)
                    lines = content.split('\n')
                    summary_lines = []
                    char_count = 0
                    
                    for line in lines[:20]:
                        if char_count + len(line) < 1000:
                            summary_lines.append(line)
                            char_count += len(line)
                        else:
                            break
                    
                    summary = "\n".join(summary_lines)
                    if len(content) > char_count:
                        summary += "\n\n... (truncated)"
                    
                    return {
                        "success": True,
                        "readme_path": readme_path,
                        "content": content,
                        "summary": summary,
                        "full_content": content
                    }
                except Exception as e:
                    return {
                        "success": False,
                        "error": str(e)
                    }
        
        # If no README found, create a basic one
        return {
            "success": True,
            "readme_path": None,
            "content": "",
            "summary": "No README file found in repository",
            "full_content": ""
        }
    
    @staticmethod
    def parse_python_files(repo_path):
        """Parse Python files and extract structure"""
        python_modules = []
        
        for root, dirs, files in os.walk(repo_path):
            # Skip unwanted directories
            dirs[:] = [d for d in dirs if d not in ['.git', '__pycache__', 'node_modules', 'venv']]
            
            for file in files:
                if file.endswith('.py'):
                    file_path = os.path.join(root, file)
                    try:
                        with open(file_path, 'r', encoding='utf-8') as f:
                            source_code = f.read()
                        
                        # Parse Python AST
                        tree = ast.parse(source_code)
                        
                        module_info = {
                            "file_path": file_path,
                            "module_name": file[:-3],  # Remove .py extension
                            "type": "python_module",
                            "classes": [],
                            "functions": [],
                            "imports": [],
                            "source_code": source_code
                        }
                        
                        for node in ast.walk(tree):
                            if isinstance(node, ast.ClassDef):
                                module_info["classes"].append({
                                    "name": node.name,
                                    "line": node.lineno,
                                    "type": "class"
                                })
                            elif isinstance(node, ast.FunctionDef):
                                module_info["functions"].append({
                                    "name": node.name,
                                    "line": node.lineno,
                                    "type": "function"
                                })
                            elif isinstance(node, ast.Import):
                                for alias in node.names:
                                    module_info["imports"].append({
                                        "name": alias.name,
                                        "alias": alias.asname
                                    })
                            elif isinstance(node, ast.ImportFrom):
                                if node.module:
                                    module_info["imports"].append({
                                        "name": node.module,
                                        "alias": None,
                                        "from_import": True
                                    })
                        
                        python_modules.append(module_info)
                        
                    except Exception as e:
                        print(f"⚠️ Error parsing {file_path}: {e}")
                        # Add basic module info even if parsing fails
                        python_modules.append({
                            "file_path": file_path,
                            "module_name": file[:-3],
                            "type": "python_module",
                            "classes": [],
                            "functions": [],
                            "imports": [],
                            "error": str(e)
                        })
        
        return python_modules
    
    @staticmethod
    def parse_jac_files(repo_path):
        """Parse Jac files and extract structure"""
        jac_modules = []
        
        for root, dirs, files in os.walk(repo_path):
            dirs[:] = [d for d in dirs if d not in ['.git', '__pycache__', 'node_modules']]
            
            for file in files:
                if file.endswith('.jac'):
                    file_path = os.path.join(root, file)
                    try:
                        with open(file_path, 'r', encoding='utf-8') as f:
                            source_code = f.read()
                        
                        # Simple Jac parser (basic structure extraction)
                        module_info = {
                            "file_path": file_path,
                            "module_name": file[:-4],  # Remove .jac extension
                            "type": "jac_module",
                            "nodes": [],
                            "walkers": [],
                            "edges": [],
                            "source_code": source_code
                        }
                        
                        lines = source_code.split('\n')
                        for i, line in enumerate(lines):
                            line = line.strip()
                            if line.startswith('node ') and '{' in line:
                                node_name = line.split()[1]
                                module_info["nodes"].append({
                                    "name": node_name,
                                    "line": i + 1,
                                    "type": "node"
                                })
                            elif line.startswith('walker ') and '{' in line:
                                walker_name = line.split()[1]
                                module_info["walkers"].append({
                                    "name": walker_name,
                                    "line": i + 1,
                                    "type": "walker"
                                })
                            elif line.startswith('edge ') and '{' in line:
                                edge_name = line.split()[1]
                                module_info["edges"].append({
                                    "name": edge_name,
                                    "line": i + 1,
                                    "type": "edge"
                                })
                        
                        jac_modules.append(module_info)
                        
                    except Exception as e:
                        print(f"⚠️ Error parsing {file_path}: {e}")
                        jac_modules.append({
                            "file_path": file_path,
                            "module_name": file[:-4],
                            "type": "jac_module",
                            "nodes": [],
                            "walkers": [],
                            "edges": [],
                            "error": str(e)
                        })
        
        return jac_modules
    
    @staticmethod
    def build_relationship_graph(python_modules, jac_modules):
        """Build relationship graph between modules"""
        relationships = {
            "imports": [],
            "calls": [],
            "inherits": []
        }
        
        all_modules = python_modules + jac_modules
        
        return {
            "python_modules": python_modules,
            "jac_modules": jac_modules,
            "relationships": relationships,
            "all_modules": all_modules,
            "total_python": len(python_modules),
            "total_jac": len(jac_modules)
        }
    
    @staticmethod
    def generate_markdown_document(repo_data, code_graph, output_path, github_url):
        """Generate comprehensive markdown documentation"""
        repo_name = repo_data.get('file_tree', {}).get('name', 'repository')
        
        # Create output directory
        output_dir = os.path.join(output_path, repo_name)
        os.makedirs(output_dir, exist_ok=True)
        
        # Build repository structure string
        def build_structure_tree(node, depth=0):
            indent = "  " * depth
            if node['is_directory']:
                result = f"{indent}📁 {node['name']}/\n"
                for child in node.get('children', []):
                    result += build_structure_tree(child, depth + 1)
            else:
                file_emoji = "📄"
                if node.get('file_type') == '.py':
                    file_emoji = "🐍"
                elif node.get('file_type') == '.jac':
                    file_emoji = "🎯"
                elif node.get('file_type') == '.md':
                    file_emoji = "📝"
                result = f"{indent}{file_emoji} {node['name']}\n"
            return result
        
        structure_tree = build_structure_tree(repo_data.get('file_tree', {}))
        
        markdown_content = f"""# 🎯 {repo_name} Documentation

*Generated by Codebase Genius • Erick's AI Documentation System*

---

## 📖 Project Overview

{repo_data.get('readme_summary', {}).get('summary', 'No README summary available')}

**Repository**: [{github_url}]({github_url})  
**Generated on**: {import datetime; datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")}  
**Total files**: {repo_data.get('file_count', 0)}  
**Total directories**: {repo_data.get('directory_count', 0)}

---

## 📁 Repository Structure
