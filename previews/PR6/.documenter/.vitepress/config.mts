import { defineConfig } from 'vitepress'
import { withMermaid } from 'vitepress-plugin-mermaid'

export default withMermaid(defineConfig({
  base: '/whanyu1212.github.io/NimbleAgents.jl/previews/PR6/',
  title: 'NimbleAgents.jl',
  description: 'A simple, lightweight framework for building AI agents in pure Julia',
  lastUpdated: true,
  cleanUrls: true,
  outDir: '../1',
  head: [['link', { rel: 'icon', href: 'REPLACE_ME_DOCUMENTER_VITEPRESS_FAVICON' }]],
  ignoreDeadLinks: true,

  markdown: {
    theme: {
      light: 'github-light',
      dark: 'github-dark',
    },
  },

  themeConfig: {
    outline: 'deep',
    
    search: {
      provider: 'local',
      options: {
        detailedView: true,
      },
    },
    nav: [
      { text: 'Home', link: '/index' },
      { text: 'Getting Started', link: '/getting_started' },
      {
        text: 'Guide',
        items: [
          { text: 'Agents', link: '/guide/agents' },
          { text: 'Tools', link: '/guide/tools' },
          { text: 'Sessions & Artifacts', link: '/guide/sessions' },
          { text: 'Multi-Agent Patterns', link: '/guide/multi_agent' },
          { text: 'Guardrails', link: '/guide/guardrails' },
          { text: 'MCP', link: '/guide/mcp' },
          { text: 'Skills', link: '/guide/skills' },
          { text: 'Tracer', link: '/guide/tracer' },
        ],
      },
      { text: 'Examples', link: '/examples' },
      { text: 'Reference', link: '/reference' },
    ],
    sidebar: [
      { text: 'Home', link: '/index' },
      { text: 'Getting Started', link: '/getting_started' },
      {
        text: 'Guide',
        collapsed: false,
        items: [
          { text: 'Agents', link: '/guide/agents' },
          { text: 'Tools', link: '/guide/tools' },
          { text: 'Sessions & Artifacts', link: '/guide/sessions' },
          { text: 'Multi-Agent Patterns', link: '/guide/multi_agent' },
          { text: 'Guardrails', link: '/guide/guardrails' },
          { text: 'MCP', link: '/guide/mcp' },
          { text: 'Skills', link: '/guide/skills' },
          { text: 'Tracer', link: '/guide/tracer' },
        ],
      },
      { text: 'Examples', link: '/examples' },
      { text: 'Reference', link: '/reference' },
    ],
    editLink: { pattern: "https://https://github.com/whanyu1212/NimbleAgents.jl/edit/develop/docs/src/:path" },
    socialLinks: [
      { icon: 'github', link: 'https://github.com/whanyu1212/NimbleAgents.jl' },
    ],
    footer: {
      message:
        'Made with <a href="https://documenter.juliadocs.org/stable/" target="_blank"><strong>Documenter.jl</strong></a> & <a href="https://vitepress.dev" target="_blank"><strong>VitePress</strong></a><br>',
      copyright: `© Copyright ${new Date().getUTCFullYear()} NimbleAgents contributors.`,
    },
  },
  mermaid: {},
}))
