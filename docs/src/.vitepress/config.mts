import { defineConfig } from 'vitepress'

export default defineConfig({
  base: 'REPLACE_ME_DOCUMENTER_VITEPRESS',
  title: 'REPLACE_ME_DOCUMENTER_VITEPRESS',
  description: 'A simple, lightweight framework for building AI agents in pure Julia',
  lastUpdated: true,
  cleanUrls: true,
  outDir: 'REPLACE_ME_DOCUMENTER_VITEPRESS',
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
    logo: 'REPLACE_ME_DOCUMENTER_VITEPRESS',
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
          { text: 'MCP', link: '/guide/mcp' },
          { text: 'Skills', link: '/guide/skills' },
        ],
      },
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
          { text: 'MCP', link: '/guide/mcp' },
          { text: 'Skills', link: '/guide/skills' },
        ],
      },
      { text: 'Reference', link: '/reference' },
    ],
    editLink: 'REPLACE_ME_DOCUMENTER_VITEPRESS',
    socialLinks: [
      { icon: 'github', link: 'REPLACE_ME_DOCUMENTER_VITEPRESS' },
    ],
    footer: {
      message:
        'Made with <a href="https://documenter.juliadocs.org/stable/" target="_blank"><strong>Documenter.jl</strong></a> & <a href="https://vitepress.dev" target="_blank"><strong>VitePress</strong></a><br>',
      copyright: `© Copyright ${new Date().getUTCFullYear()} NimbleAgents contributors.`,
    },
  },
})
