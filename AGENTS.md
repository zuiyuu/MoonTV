# Agent Guidelines for MoonTV

This document provides comprehensive guidelines for coding agents working on the MoonTV project. MoonTV is a Next.js 14 TypeScript application for video streaming aggregation.

## Build, Lint, and Test Commands

### Development & Build

```bash
# Development server with hot reload
pnpm dev

# Production build (includes runtime and manifest generation)
pnpm build

# Start production server
pnpm start
```

### Code Quality & Testing

```bash
# Lint code (Next.js ESLint rules)
pnpm lint

# Auto-fix linting issues and format code
pnpm lint:fix

# Type checking (strict TypeScript)
pnpm typecheck

# Run all tests
pnpm test

# Run tests in watch mode
pnpm test:watch

# Run a specific test file
pnpm test -- path/to/test/file.test.ts

# Run tests matching a pattern
pnpm test -- --testNamePattern="should handle"
```

### Code Generation

```bash
# Generate runtime configuration
pnpm gen:runtime

# Generate PWA manifest
pnpm gen:manifest

# Generate changelog
pnpm gen:changelog
```

### Formatting

```bash
# Format all files with Prettier
pnpm format

# Check if files are formatted correctly
pnpm format:check
```

## Code Style Guidelines

### Import Organization

Imports must be organized using `simple-import-sort` with the following order:

1. **External libraries & side effects**: `^@?\\w`, `^\\u0000`
2. **CSS files**: `^.+\\.s?css$`
3. **Internal libraries & hooks**: `^@/lib`, `^@/hooks`
4. **Static data**: `^@/data`
5. **Components & containers**: `^@/components`, `^@/container`
6. **Zustand stores**: `^@/store`
7. **Other internal imports**: `^@/`
8. **Type imports**: `^@/types`
9. **Relative imports**: `^\\./?$`, `^\\.(?!/?$)`, etc.

Example:

```typescript
// External libraries
import { useState, useEffect } from 'react';
import { CheckCircle } from 'lucide-react';

// CSS files
import 'tailwindcss/base';

// Internal libraries
import { db } from '@/lib/db.client';
import { processImageUrl } from '@/lib/utils';

// Components
import { ImagePlaceholder } from '@/components/ImagePlaceholder';

// Types
import type { SearchResult } from '@/lib/types';

// Relative imports
import { config } from './config';
```

### Formatting Rules (Prettier)

```javascript
{
  arrowParens: 'always',
  singleQuote: true,
  jsxSingleQuote: true,
  tabWidth: 2,
  semi: true
}
```

### TypeScript Configuration

- **Strict mode**: Enabled
- **Target**: ES5
- **Module resolution**: Node16
- **JSX**: Preserve
- **Path mapping**: `@/*` → `./src/*`, `~/*` → `./public/*`

### Component Patterns

#### React Components

- Use functional components with hooks
- Prefer named exports over default exports
- Use proper TypeScript interfaces for props
- Include display names for debugging

```typescript
interface VideoCardProps {
  id?: string;
  title?: string;
  // ... other props
}

export default function VideoCard({ id, title }: VideoCardProps) {
  // Component logic
}
```

#### Hooks Usage

- Use `useCallback` for event handlers passed to child components
- Use `useMemo` for expensive computations
- Include proper dependency arrays
- Use descriptive variable names

#### Error Handling

- Use try-catch blocks for async operations
- Provide meaningful error messages
- Log errors appropriately (console.error for debugging)
- Handle loading states properly

```typescript
try {
  const result = await someAsyncOperation();
  // Handle success
} catch (error) {
  console.error('Operation failed:', error);
  // Handle error gracefully
}
```

### Naming Conventions

#### Files and Directories

- **Components**: PascalCase (`VideoCard.tsx`)
- **Utilities**: camelCase (`utils.ts`)
- **Types**: PascalCase with `Types` suffix (`admin.types.ts`)
- **API routes**: kebab-case (`search-history/route.ts`)
- **Directories**: lowercase with hyphens if needed (`api/search`)

#### Variables and Functions

- **Constants**: SCREAMING_SNAKE_CASE
- **Functions**: camelCase
- **Components**: PascalCase
- **Hooks**: camelCase with `use` prefix
- **Types/Interfaces**: PascalCase
- **Enums**: PascalCase

#### CSS Classes

- Use Tailwind CSS utility classes
- Follow component-based naming
- Use responsive prefixes consistently
- Maintain dark mode support

### ESLint Rules

#### Critical Rules (will fail CI)

- No unused imports (`unused-imports/no-unused-imports`)
- No unused variables (`unused-imports/no-unused-vars`)
- Import sorting (`simple-import-sort/imports`)
- TypeScript recommended rules
- Next.js core web vitals

#### Warning Rules

- Console statements (`no-console`: 'warn')
- JSX curly brace presence
- Explicit module boundary types (disabled)

### Testing Guidelines

#### Test Setup

- Uses Jest with jsdom environment
- Next.js router mocking enabled
- Testing Library integration

#### Test File Organization

- Test files should be colocated with components
- Use `.test.tsx` or `.test.ts` extension
- Follow naming pattern: `ComponentName.test.tsx`

#### Testing Patterns

```typescript
import { render, screen, fireEvent } from '@testing-library/react';
import Component from './Component';

describe('Component', () => {
  it('should render correctly', () => {
    render(<Component />);
    expect(screen.getByText('expected text')).toBeInTheDocument();
  });

  it('should handle user interactions', () => {
    render(<Component />);
    fireEvent.click(screen.getByRole('button'));
    // Assertions
  });
});
```

### Commit Message Convention

Follow conventional commits with these types:

- `feat`: New features
- `fix`: Bug fixes
- `docs`: Documentation changes
- `chore`: Maintenance tasks
- `style`: Code style changes
- `refactor`: Code refactoring
- `ci`: CI/CD changes
- `test`: Testing changes
- `perf`: Performance improvements
- `revert`: Reverts
- `vercel`: Vercel-specific changes

Examples:

```
feat: add dark mode toggle component
fix: resolve video playback on mobile devices
chore: update dependencies to latest versions
```

### Project Structure

```
src/
├── app/                 # Next.js App Router pages
│   ├── api/            # API routes
│   ├── layout.tsx      # Root layout
│   └── page.tsx        # Home page
├── components/         # Reusable UI components
├── lib/               # Utility functions and configurations
│   ├── utils.ts       # General utilities
│   ├── types.ts       # TypeScript type definitions
│   ├── db.ts          # Database operations
│   └── config.ts      # Configuration management
└── styles/            # Global styles and CSS modules
```

### Security Best Practices

- Never commit sensitive data (API keys, passwords, tokens)
- Use environment variables for configuration
- Validate user inputs on both client and server
- Implement proper authentication for admin routes
- Use HTTPS in production
- Sanitize HTML content before rendering

### Performance Considerations

- Use Next.js Image component for optimized images
- Implement proper code splitting
- Use React.memo for expensive components
- Optimize bundle size with tree shaking
- Implement proper caching strategies

### Deployment

- Support for Vercel, Docker, and Netlify
- Multiple storage backends: localStorage, Redis, Upstash, D1
- Environment-based configuration
- PWA support for offline functionality

## Quality Assurance Checklist

Before committing changes:

1. **Run type checking**: `pnpm typecheck`
2. **Run linting**: `pnpm lint`
3. **Run tests**: `pnpm test`
4. **Format code**: `pnpm format`
5. **Verify build**: `pnpm build`

## Reference Patterns

### API Route Structure

```typescript
// src/app/api/example/route.ts
import { NextRequest, NextResponse } from 'next/server';

export async function GET(request: NextRequest) {
  try {
    // API logic
    return NextResponse.json({ success: true });
  } catch (error) {
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 },
    );
  }
}
```

### Component with Error Boundaries

```typescript
'use client';

import { useState, useEffect } from 'react';

export default function DataComponent() {
  const [data, setData] = useState(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchData()
      .then(setData)
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error}</div>;

  return <div>{/* Render data */}</div>;
}
```

### Custom Hook Pattern

```typescript
import { useState, useEffect } from 'react';

export function useLocalStorage<T>(
  key: string,
  initialValue: T,
): [T, (value: T) => void] {
  const [storedValue, setStoredValue] = useState<T>(() => {
    try {
      const item = window.localStorage.getItem(key);
      return item ? JSON.parse(item) : initialValue;
    } catch (error) {
      return initialValue;
    }
  });

  const setValue = (value: T) => {
    try {
      setStoredValue(value);
      window.localStorage.setItem(key, JSON.stringify(value));
    } catch (error) {
      console.error('Error saving to localStorage:', error);
    }
  };

  return [storedValue, setValue];
}
```

This document should be updated whenever new patterns or conventions are established in the codebase.</content>
<parameter name="filePath">D:\MoonTV\AGENTS.md
