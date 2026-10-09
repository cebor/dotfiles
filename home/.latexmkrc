# PDF previewer: Skim on macOS, a detected viewer elsewhere (Linux/WSL)
if ($^O eq 'darwin') {
    $pdf_previewer = 'open -a Skim';
} else {
    $pdf_previewer = 'start xdg-open';   # fallback
    my @viewers = ('zathura', 'okular', 'evince');
    # winopen only under WSL: elsewhere it is on PATH too, but has no Windows
    if (open(my $fh, '<', '/proc/version')) {
        push @viewers, 'winopen' if <$fh> =~ /microsoft/i;
        close $fh;
    }
    for my $viewer (@viewers) {
        if (system("command -v $viewer >/dev/null 2>&1") == 0) {
            $pdf_previewer = "start $viewer";
            last;
        }
    }
}
$pdflatex = 'pdflatex -synctex=1 -interaction=nonstopmode';
@generated_exts = (@generated_exts, 'synctex.gz');
