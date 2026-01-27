# Claude Code Documentation

## Overview

Claude Code is Anthropic's official CLI tool that brings Claude's capabilities directly to your terminal. It's designed for software development tasks, offering interactive assistance with coding, debugging, and project management.

## Installation

Claude Code is automatically installed by the `init.sh` script in this repository. The installation:
- Installs to `~/.local/bin/claude`
- Adds the binary to your PATH via `.bashrc`
- Version installed: 2.1.20

### Manual Installation

If you need to install manually:
```bash
curl -fsSL https://claude.ai/install.sh | bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

## Getting Started

### Basic Usage

```bash
# Start an interactive session
claude

# Run a specific command
claude "explain this code"

# Get help
claude --help

# Check version
claude --version
```

### Working with Files

```bash
# Analyze a file
claude "review this code" file.py

# Work with multiple files
claude "refactor these files" src/*.js

# Edit files interactively
claude "add error handling to main.py"
```

## Key Features

### 1. Code Generation & Editing
- Write new code based on specifications
- Refactor existing code
- Add features to existing projects
- Generate boilerplate and templates

### 2. Code Review & Analysis
- Review code for bugs and improvements
- Analyze code architecture
- Suggest optimizations
- Check for security issues

### 3. Debugging
- Help diagnose errors
- Suggest fixes for bugs
- Explain error messages
- Debug complex issues

### 4. Documentation
- Generate documentation
- Explain complex code
- Create README files
- Write API documentation

### 5. Testing
- Generate unit tests
- Create test cases
- Review test coverage
- Suggest testing strategies

## Advanced Usage

### Environment Variables

```bash
# Set API key (if needed)
export ANTHROPIC_API_KEY="your-api-key"

# Configure model preference
export CLAUDE_MODEL="claude-3-sonnet-20240229"
```

### Working Directory

Claude Code is context-aware and works best when run from your project root:
```bash
cd /path/to/your/project
claude "analyze the project structure"
```

### Interactive Mode

Start an interactive session for extended conversations:
```bash
claude
> Can you explain the authentication flow?
> Now add rate limiting to the API
> Run the tests
```

## Integration with Development Workflow

### Git Integration

Claude Code can help with Git operations:
```bash
claude "review my changes before commit"
claude "write a commit message for these changes"
claude "help me resolve this merge conflict"
```

### CI/CD

Use Claude Code in automation:
```bash
# In a script
claude "check if tests cover the new feature" --non-interactive
```

## Best Practices

1. **Be Specific**: Provide clear instructions and context
   - Good: "Add error handling to the user login function in auth.py"
   - Less effective: "Fix the code"

2. **Provide Context**: Include relevant files and information
   ```bash
   claude "optimize this function" --context="high traffic endpoint"
   ```

3. **Iterative Refinement**: Work incrementally
   - Review suggestions before applying
   - Test changes as you go
   - Provide feedback for improvements

4. **Use Project Context**: Run from project root for better understanding
   ```bash
   cd /workspace/my-project
   claude "add a new API endpoint for user profiles"
   ```

## Common Use Cases

### Starting a New Feature
```bash
claude "create a REST API endpoint for user authentication with JWT tokens"
```

### Debugging
```bash
claude "this error occurs when submitting the form: TypeError: Cannot read property 'value' of null"
```

### Code Review
```bash
claude "review pull-request.diff for potential issues"
```

### Refactoring
```bash
claude "refactor this class to use dependency injection"
```

### Testing
```bash
claude "write unit tests for the UserService class"
```

## Troubleshooting

### Command Not Found

If `claude` command is not found:
```bash
# Reload your shell configuration
source ~/.bashrc

# Or verify the PATH
echo $PATH | grep ".local/bin"

# Check if binary exists
ls -la ~/.local/bin/claude
```

### Authentication Issues

If you encounter authentication errors:
```bash
# Check API key configuration
claude auth status

# Re-authenticate
claude auth login
```

### Performance

For better performance:
- Work with smaller file sets when possible
- Be specific about what files to analyze
- Use focused, targeted questions

## Resources

- **Official Documentation**: [https://claude.ai/docs](https://claude.ai/docs)
- **GitHub Issues**: Report bugs and request features
- **Community**: Join discussions about Claude Code usage

## Related Tools

### OpenCode.ai

OpenCode is also installed by `init.sh`. It provides additional AI coding assistance:
```bash
opencode  # Start OpenCode session
```

## Tips & Tricks

1. **Combine with tmux**: Run Claude in a separate pane for easy reference
   ```bash
   tmux split-window -h claude
   ```

2. **Pipe output**: Use Claude with other tools
   ```bash
   git diff | claude "summarize these changes"
   ```

3. **Save sessions**: Keep important conversations
   ```bash
   claude > session.log
   ```

4. **Project templates**: Use Claude to scaffold new projects
   ```bash
   claude "create a Python FastAPI project structure with tests"
   ```

## Updates

Keep Claude Code up to date:
```bash
# Update to latest version
curl -fsSL https://claude.ai/install.sh | bash
```

## Security Notes

- Never commit API keys to version control
- Review all code changes before applying
- Use `.env` files for sensitive configuration
- Be cautious with system-level operations

## Limits & Considerations

- Respect rate limits for API calls
- Large codebases may need to be analyzed in chunks
- Complex architectural changes should be reviewed carefully
- Always test generated code before deploying

---

For more information and updates, visit [https://claude.ai](https://claude.ai)
