# PDF previewer: Skim on macOS, a detected viewer elsewhere (Linux/WSL)
if ($^O eq 'darwin') {
    $pdf_previewer = 'open -a Skim';
} else {
    $pdf_previewer = 'start xdg-open';   # fallback
    for my $viewer ('zathura', 'okular', 'evince', 'winopen') {
        if (system("command -v $viewer >/dev/null 2>&1") == 0) {
            $pdf_previewer = "start $viewer";
            last;
        }
    }
}
$pdflatex = 'pdflatex -synctex=1 -interaction=nonstopmode';
@generated_exts = (@generated_exts, 'synctex.gz');
