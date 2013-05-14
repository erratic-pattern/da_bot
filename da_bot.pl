#!/usr/bin/perl -w

use strict;
use LWP::Simple;
use HTML::Parser;
use File::Spec;
use HTML::Entities;

print 'deviantart username: ';
my $username = <STDIN>;
chomp $username;
print "\n";

my $gname = '';
my $gallery = "http://$username.deviantart.com/gallery/?offset=0";
my %galleries = ();
my %links = ();

my $is_sub  = 0;
my $sub_name = '';

my $is_title = 0;
my $dl_link = '';
my $dl_title = '';

my $first_run = 1;

my $p;

sub has_links {
	return shift !~ m/This section has no deviations yet!/;
}

sub gallery_start {
	my ($tag, $attr) = @_;
	if ($first_run && $tag eq 'div') {
		$is_sub = 1 if $attr->{class} && $attr->{class} eq 'tv150-tag';
	}
	elsif ($tag eq 'a') {
		if ($is_sub) {
			$galleries{$sub_name} = $attr->{href};
			$sub_name = "";
			$is_sub = 0;
		}
		elsif ($attr->{class} && ($attr->{class} =~ m/thumb/)) {
			@{$links{$gname}} = grep {$_ ne $attr->{href}} @{$links{$gname}};
			#@{$links{''}} = grep {$_ ne $attr->{href}} @{$links{''}} if $gname; 
			push @{$links{$gname}}, $attr->{href}; 
		}
	}
}

sub gallery_text {
	if ($is_sub && !$sub_name) {
		$sub_name = shift;
	}
}

sub dev_start {
	my ($tag, $attr) = @_;
	if ($tag eq 'title')
	{
		$is_title = 1;
	}
	elsif ($tag eq 'a')
	{
		if ($attr->{id} && $attr->{id} eq 'download-button')
		{
			$dl_link = $attr->{href};
			$p->eof();
		}
	}
}

sub dev_text {
	if ($is_title) {
		$dl_title = shift;
		$dl_title =~ s/by .*//;
		$is_title = 0;
	}
}
sub gallery_loop {
	my $text = get $gallery;
	my $offset = 0;
	while ($text) {
		$p->parse($text);
		$first_run = 0;
		$offset += 24;
		$gallery .= "?offset=$offset" unless $gallery =~ s/\?offset\=[0-9]+/\?offset\=$offset/;
		$text = get $gallery;
		last unless has_links $text;
	}
}

sub dehtml {
	local $/ = undef;
	local $_ = shift;
	my ($f1, $f2, $html);
	open $f1, $_;
	$html = <$f1>;
	close $f1;
	$html =~ m/<body>(.*?)<\/body>/s;
	$html = $1;
	$html =~ s/\r?\n//sg;
	$html =~ s/<br \/>/\r\n/g;
	$html =~ s/<.*?>//g;
	$html = decode_entities($html);
	s/\.html/\.txt/;
	open $f2, ">$_";
	print $f2 $html;
	close $f2;
}

$p = HTML::Parser->new;
$p->unbroken_text(1);
$p->handler(start => \&gallery_start, 'tag, attr');
$p->handler(text => \&gallery_text, 'text');
$p->report_tags(qw(a div));
gallery_loop();
gallery_loop() while (($gname, $gallery) = each %galleries);

$p = HTML::Parser->new;
$p->unbroken_text(1);
$p->handler(start => \&dev_start, 'tag, attr');
$p->handler(text => \&dev_text, 'dtext');
$p->report_tags(qw(title a));
my $output = 'art';
`mkdir "$output"`;
while (my ($name,$links) = each %links) {
	`mkdir "$output/$name"` if $name;
	for (@$links) {
		$p->parse(get $_);
		#print "$dl_title: $dl_link\n";
		$dl_link =~ m/.*?\.(.{3,4})$/;
		my $path = "$output/@{[$name ? \"$name/\" : '']}$dl_title.$1";

		open F, ">$path" or die "Couldn't open: $!";
		print F (get $dl_link);
		close F;
		dehtml $path if $1 eq "html";
	}
}
