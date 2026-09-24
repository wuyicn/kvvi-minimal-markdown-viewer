# Design QA — compact table and softer text palette

- Source visual truth: `/var/folders/43/w0dv_7_n7hlb0kvtqs6bb4_00000gn/T/codex-clipboard-7dd8b76f-2383-4207-ade4-91acc1733b68.png`
- Implementation screenshot: `cua://app/com.kewei.mdreader/window/可微MD极简阅读器?document=sample.md&captured=2026-09-24T10:17+08:00`
- Source pixels: 4248 × 1626; the left pane is the selected visual target.
- Implementation capture: native macOS window on a Retina display, light appearance, `sample.md`, default 17 px reader size.
- Normalization: the source and implementation contain different documents and window proportions, so QA compares the shared content region and visual tokens rather than line-for-line geometry.

## Full-view comparison evidence

The implementation now follows the selected left-side direction: neutral gray-black body copy, slightly stronger but non-black headings, softened quotes, a compact table, a very light header fill, low-contrast grid lines, and subtle alternating rows. The content column and surrounding white space remain unchanged because the request is limited to table treatment and global text tone.

## Focused table comparison evidence

The table region was inspected separately because it is the critical fidelity surface. Real WebKit computed-style tests verify a 0.92 em table size, 7 × 12 px cell padding, 1.5 line height, `#f7f8fa` header fill, `#dfe3e8` borders, 600 header weight, and `#fafbfc` alternating rows. The native-window capture confirms that the resulting table is lighter and denser than the previous version.

## Required fidelity surfaces

- Fonts and typography: system/PingFang stack preserved; body line height reduced from 1.75 to 1.68; table uses 0.92 em/1.5; headings and strong text use a softer `#2f343b`.
- Spacing and layout rhythm: global page geometry preserved; table rows are more compact and retain adequate reading space.
- Colors and visual tokens: body `#3a3e44`, headings `#2f343b`, muted text `#757c85`, borders `#dfe3e8`; matching dark-mode tokens were added.
- Image quality and assets: no visual assets were changed or replaced.
- Copy and content: no Markdown content or interface labels were changed.

## Findings

No actionable P0, P1, or P2 mismatch remains within the approved scope.

## Comparison history

- Initial state: table had transparent headers, darker borders, full-size text, 8 px vertical padding, and uniformly dark foreground text.
- Fix: introduced semantic light/dark tokens, compact table metrics, pale header/alternate-row surfaces, and differentiated body/heading/muted colors.
- Post-fix evidence: native light-mode capture plus the WebKit visual-hierarchy regression test.

## Follow-up polish

- P3: Recheck the palette on a physical dark-mode desktop if a future release changes the dark theme; automated tokens are present, but this pass visually inspected light mode only.

final result: passed
