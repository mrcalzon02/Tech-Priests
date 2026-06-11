# GUI Split Workbench 0635

Edit important chunks first.

Machine-Spirit Ledger target:
- remove `tech_priests_machine_spirit_inner_screen_0565`
- place `tech_priests_machine_spirit_tabs_0526` directly under the shell body

Work-State Reliquary target:
- edit `add_inner_screen_page_0565`
- make it create only a scroll pane, not a frame wrapping a scroll pane

After edits, manually copy the changed function chunks back into their source
files or use your editor's compare/replace tools.
