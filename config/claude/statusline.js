#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const readline = require('readline');

// ANSI color codes
const colors = {
  reset: '\x1b[0m',
  dim: '\x1b[2m',
  bold: '\x1b[1m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  cyan: '\x1b[36m',
  magenta: '\x1b[35m'
};

// Model context limits (approximate)
const MODEL_LIMITS = {
  'claude-3-5-sonnet-20241022': 200000,
  'claude-3-5-haiku-20241022': 200000,
  'claude-opus-4-1-20250805': 200000,
  'claude-3-5-sonnet-20240620': 200000,
  'claude-3-5-haiku-20240307': 200000,
  'claude-3-opus-20240229': 200000,
  'claude-3-sonnet-20240229': 200000,
  'claude-3-haiku-20240307': 200000
};

// Auto-compact thresholds (approximate)
const AUTO_COMPACT_THRESHOLD = 0.7; // 70% of context limit

// Read input from stdin
async function getInput() {
  return new Promise((resolve) => {
    let data = '';
    process.stdin.on('data', chunk => data += chunk);
    process.stdin.on('end', () => resolve(data));
  });
}

// Find and read transcript file
async function readTranscript(transcriptPath) {
  try {
    if (!fs.existsSync(transcriptPath)) {
      return null;
    }
    
    const content = fs.readFileSync(transcriptPath, 'utf8');
    const lines = content.split('\n').filter(line => line.trim());
    
    let totalTokens = 0;
    let messageCount = 0;
    
    for (const line of lines) {
      try {
        const data = JSON.parse(line);
        
        // Count input tokens
        if (data.message?.usage?.input_tokens) {
          totalTokens += data.message.usage.input_tokens;
          messageCount++;
        }
        
        // Count output tokens
        if (data.message?.usage?.output_tokens) {
          totalTokens += data.message.usage.output_tokens;
        }
        
        // Alternative format
        if (data.usage?.input_tokens) {
          totalTokens += data.usage.input_tokens;
          messageCount++;
        }
        if (data.usage?.output_tokens) {
          totalTokens += data.usage.output_tokens;
        }
      } catch (e) {
        // Skip malformed lines
      }
    }
    
    return { totalTokens, messageCount };
  } catch (error) {
    return null;
  }
}

// Format token count
function formatTokens(tokens) {
  if (tokens >= 1000000) {
    return `${(tokens / 1000000).toFixed(1)}M`;
  } else if (tokens >= 1000) {
    return `${(tokens / 1000).toFixed(1)}K`;
  }
  return tokens.toString();
}

// Get color based on percentage
function getPercentageColor(percentage) {
  if (percentage >= 0.9) return colors.red;
  if (percentage >= 0.7) return colors.yellow;
  if (percentage >= 0.5) return colors.cyan;
  return colors.green;
}

// Format directory path (shorten if too long)
function formatPath(dirPath, maxLength = 30) {
  if (dirPath.length <= maxLength) return dirPath;
  
  const parts = dirPath.split('/');
  if (parts.length <= 3) return dirPath;
  
  // Keep first and last parts
  return `${parts[1]}/.../${parts.slice(-2).join('/')}`;
}

// Main function
async function main() {
  try {
    const inputData = await getInput();
    const data = JSON.parse(inputData);
    
    const modelId = data.model?.id || 'unknown';
    const modelName = data.model?.display_name || modelId;
    const cwd = data.cwd || data.workspace?.current_dir || process.cwd();
    const transcriptPath = data.transcript_path;
    
    // Get context limit for current model
    const contextLimit = MODEL_LIMITS[modelId] || 200000;
    const autoCompactAt = Math.floor(contextLimit * AUTO_COMPACT_THRESHOLD);
    
    // Read transcript for token usage
    let tokenInfo = null;
    if (transcriptPath) {
      tokenInfo = await readTranscript(transcriptPath);
    }
    
    // Build status line components
    const components = [];
    
    // Model info
    components.push(`${colors.magenta}${modelName}${colors.reset}`);
    
    // Current directory
    const shortPath = formatPath(cwd);
    components.push(`${colors.cyan}${shortPath}${colors.reset}`);
    
    // Token usage
    if (tokenInfo && tokenInfo.totalTokens > 0) {
      const percentage = tokenInfo.totalTokens / contextLimit;
      const percentageColor = getPercentageColor(percentage);
      const percentageDisplay = `${(percentage * 100).toFixed(1)}%`;
      
      // Tokens used / limit
      const tokensDisplay = `${formatTokens(tokenInfo.totalTokens)}/${formatTokens(contextLimit)}`;
      
      // Remaining until auto-compact
      const remainingTokens = autoCompactAt - tokenInfo.totalTokens;
      const remainingDisplay = remainingTokens > 0 
        ? `${formatTokens(remainingTokens)} left`
        : `${colors.red}COMPACT SOON${colors.reset}`;
      
      components.push(
        `${colors.dim}[${colors.reset}` +
        `${percentageColor}${tokensDisplay}${colors.reset} ` +
        `${percentageColor}${percentageDisplay}${colors.reset}` +
        `${colors.dim}]${colors.reset}`
      );
      
      if (percentage >= 0.5) {
        components.push(
          `${colors.dim}(${colors.reset}` +
          `${remainingTokens > 0 ? colors.dim : colors.red}${remainingDisplay}${colors.reset}` +
          `${colors.dim})${colors.reset}`
        );
      }
      
      // Message count
      if (tokenInfo.messageCount > 0) {
        components.push(`${colors.dim}${tokenInfo.messageCount} msgs${colors.reset}`);
      }
    } else {
      // No token data available
      components.push(`${colors.dim}[No usage data]${colors.reset}`);
    }
    
    // Output the status line
    console.log(components.join(' '));
    
  } catch (error) {
    // Fallback status line on error
    console.log(`${colors.dim}Claude Code${colors.reset}`);
  }
}

// Run if executed directly
if (require.main === module) {
  main();
}