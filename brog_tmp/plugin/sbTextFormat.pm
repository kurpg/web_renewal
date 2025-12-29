#!/usr/bin/perl -w
# 
# sb::Plugin::sbTextFormat - Module for sb
# == written by T.Otani <ootani@segausers.gr.jp> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

# 記法のルールに関しては、末尾の「sbtext 記法について」をご覧ください。

# 当プラグインは the Perl Artistic License に基づき、配布されます。
# 参照 : http://www.perl.com/pub/a/language/misc/Artistic.html

# 0.10 [2006/08/03] changed detail to point new site address
# 0.11 [2007/04/12] changed get_footnote to fix a bug

package sb::Plugin::sbTextFormat;
# ==================================================
# // initialization for plugin
# ==================================================
use strict;
use sb::Plugin ();
sb::Plugin->register_plugin(
	'lang' => {
		'ja' => 'euc',
		'en' => 'ascii',
	},
	'text' => {
		'type'    => 'text format, cms',
		'name'    => 'sbtext',
		'text'    => 'sbtext',
		'author'  => 'takkyun',
		'detail'  => 'http://serenebach.net/',
		'version' => '0.11',
	},
	'file' => 'sbtext_format.txt',
	'data' => undef,
);
# テキストフォーマットプラグインとして登録
sb::Plugin->register_text_filter(
	'name'     => 'sbtext',
	'callback' => \&sb::TextFormat::sbtext::format,
);
# cms用プラグインとして登録
sb::Plugin->register_content_module(
	'type'     => 'entry',
	'callback' => \&sb::TextFormat::sbtext::content,
	'field'    => 'body_text',
);
package sb::TextFormat::sbtext;
use sb::Config ();
# ==================================================
# // declaration for constant value
# ==================================================
sub LINK_TARGET     (){ ' target="_blank"' };                               # 外部リンクターゲット設定
sub HEADING_MARK    (){ '&#9632;' };                                        # 小見出し用マーク
sub HEADING_PREFIX  (){ 'eid' };                                            # 小見出し用 id
sub LOWEST_HEADING  (){ 2 };                                                # 最小の小見出しヘッディング要素
sub MAX_BLOCK_LEVEL (){ 3 };                                                # 最大引用ネストレベル
sub FOOTNOTE_PREFIX (){ 'note' };                                           # 脚注用 id
sub NOTE_BEGIN_TAG  (){ '<sup>' };                                          # 本文内の脚注要素(開始タグ)
sub NOTE_END_TAG    (){ '</sup>' };                                         # 本文内の脚注要素(終了タグ)
sub LINK_HATENA     (){ 'http://d.hatena.ne.jp/keyword/' };                 # はてなキーワードリンク
sub LINK_GOOGLE     (){ 'http://www.google.com/search?lr=lang_ja&amp;q=' }; # Google 検索リンク
sub LINK_AMAZON     (){ 'http://www.amazon.co.jp/exec/obidos/ASIN/' };      # アマゾン商品リンク
# ==================================================
# // declaration for class member
# ==================================================
my @mFootNote = ();
my $mEntryId  = 0;
my $mAwsId    = '';
# ==================================================
# // functions for content
# ==================================================
sub content { # 本文・続き・概要
	my $cms   = shift;
	my $entry = shift;
	my %var   = @_;
	if ($entry->form eq 'sbtext') { # sbtext format
		my ($body,$more);
		@mFootNote = ();
		$mEntryId  = $entry->id;
		$mAwsId    = &_check_awsid($entry->auth) if ($mAwsId eq '');
		if ($entry->body ne '') { # 本文
			$body = $entry->formated_body;
			$body .= '<a id="sequel"></a>' if ($entry->more ne '' and $var{'mode'} eq 'ent');
		}
		if ($entry->more ne '') { # 続き
			my $permalink = &sb::Content::Entry::_permalink($entry,$var{'cat'},'more',$var{'mode'});
			$more = ($var{'mode'} eq 'ent') 
			      ? $entry->formated_more 
			      : '<a href="' . $permalink . '">' . $var{'lang'}->string('parts_sequel') . '</a>';
		}
		my $footnote = &get_footnote($entry->id,\$body,\$more);
		if ($var{'mode'} ne 'ent' and $more eq '') {
			$body .= $footnote;
		} else {
			$more .= $footnote;
		}
		$cms->tag('entry_description'=>$body) if ($body ne '');
		$cms->tag('entry_sequel'=>$more) if ($more ne '');
		$cms->tag('entry_excerpt'=>$entry->sum);
	} else { # other format
		&sb::Content::Entry::_body_text($cms,$entry,%var);
	}
}
sub get_footnote($$$)
{
	my ($id,$body,$more) = @_;
	my $footnote = '';
	if (@mFootNote)
	{ # 脚注処理
		$footnote .= '<ul class="footnote">';
		my $bgn = NOTE_BEGIN_TAG;
		my $end = NOTE_END_TAG;
		my $symbol = FOOTNOTE_PREFIX . $id . '-';
		my $note_in_body = $$body =~ s!<sbnote />!<sbnote />!g;
		for (my $i=0;$i<@mFootNote;$i++) {
			my $text = &_inline($mFootNote[$i]);
			my $num = $i + 1;
			my $note = $symbol . $i;
			my $mark = $symbol . $i . '-body';
			if ($i < $note_in_body) {
				$$body =~ s!<sbnote />!$bgn<a href="#$note" id="$mark" title="$text">\*$num</a>$end!;
			} else {
				$$more =~ s!<sbnote />!$bgn<a href="#$note" id="$mark" title="$text">\*$num</a>$end!;
			}
			$footnote .= "\n<li id=\"$note\"><a href=\"#$mark\">*$num</a> : $text</li>";
		}
		$footnote .= "\n</ul>";
	}
	return $footnote;
}
# ==================================================
# // private functions - other utilities
# ==================================================
sub _check_awsid { # アマゾンアソシエイト ID の読み込み
	my $id = shift;
	my $user = sb::Data->load('User','id'=>$id);
	return ($user and $user->aws ne '') ? $user->aws : 'simpleboxes-22';
}
# ==================================================
# // functions for text format
# ==================================================
sub format { # テキストフォーマットメイン
	my $text = shift; # 入力パラメータ
	@mFootNote = (); # reset buffer
	$text = sb::Text->entitize($text);
	$text = &_shelter_letters($text);
	$text = &_shelter_footnote($text);
	$text = &_hatena_block($text);
	$text = &_blocks($text);
	$text = &_return_letters($text);
	$text = &_finishing($text);
	return($text);
}
# ==================================================
# // private functions - text utilities
# ==================================================
sub _finishing { # 終了処理
	my $text = shift;
	$text =~ s!<p(.*?)>\n!<p$1>!g;
	$text =~ s!<pre>\n!<pre>!g;
	$text =~ s!\n</pre>!</pre>!g;
	$text =~ s!<p></p>\n!!g;
	$text =~ s!<br />\n</p>!</p>!g;
	return($text);
}
sub _shelter_letters { # 特殊文字の退避
	my $text = shift;
	$text =~ s/\\\\/&sb_;/g;
	$text =~ s/\\\^/&sba;/g;
	$text =~ s/\\\*/&sbb;/g;
	$text =~ s/\\\&lt;/&sbc;/g;
	$text =~ s/\\\'/&sbd;/g; # escape '
	$text =~ s/\\\(/&sbe;/g;
	$text =~ s/\\\[/&sbf;/g;
	$text =~ s/\\\|/&sbg;/g;
	$text =~ s/\\\-/&sbh;/g;
	$text =~ s/\\\+/&sbi;/g;
	$text =~ s/\\\:/&sbj;/g;
	$text =~ s/\\\#/&sbk;/g;
	$text =~ s/\\\)/&sbl;/g;
	$text =~ s/\\\]/&sbm;/g;
	$text =~ s/\\\&amp;/&sbn;/g;
	return($text);
}
sub _return_letters { # 特殊文字の復帰
	my $text = shift;
	$text =~ s/\&sbn;/\&amp;/g;
	$text =~ s/\&sbm;/\]/g;
	$text =~ s/\&sbl;/\)/g;
	$text =~ s/\&sbk;/\#/g;
	$text =~ s/\&sbj;/\:/g;
	$text =~ s/\&sbi;/\+/g;
	$text =~ s/\&sbh;/\-/g;
	$text =~ s/\&sbg;/\|/g;
	$text =~ s/\&sbf;/\[/g;
	$text =~ s/\&sbe;/\(/g;
	$text =~ s/\&sbd;/\'/g; # unescape '
	$text =~ s/\&sbc;/\&lt;/g;
	$text =~ s/\&sbb;/\*/g;
	$text =~ s/\&sba;/\^/g;
	$text =~ s/\&sb_;/\\/g;
	return($text);
}
sub _shelter_footnote { # 脚注のバッファ処理
	my $text = shift;
	push(@mFootNote,$1) while ( $text =~ s/\(\((.*?)\)\)/<sbnote \/>/ );
	return($text);
}
sub _hatena_block { # はてな風ブロックの処理
	my $text = shift;
	my @result = ();
	my $quote = -1;
	my $pre   = -1;
	$quote = 0 if ($text =~ /&gt;&gt;.*\n&lt;&lt;/s);
	$pre   = 0 if ($text =~ /&gt;\|\|\n.*\n\|\|&lt;/s);
	return($text) if ($quote == -1 and $pre == -1);
	my @buf = split("\n",$text);
	foreach my $line (@buf) {
		if ($line =~ /^&lt;&lt;$/) {
			$quote--;
			$quote = 0 if ($quote < 0);
			next;
		} elsif ($line =~ /^\|\|&lt;$/) {
			$pre = 0;
			next;
		}
		if ($quote >= 0 and $line =~ /^&gt;&gt;(.*)$/) {
			my $check = $1;
			if ($check =~ /^=/ or $check eq '') {
				$quote++;
				$quote = MAX_BLOCK_LEVEL if ($quote > MAX_BLOCK_LEVEL);
				$line = $check;
				next if ($line eq '');
			}
		} elsif ($pre >= 0 and $line =~ /^&gt;\|\|$/) {
			$pre = 1;
			next;
		}
		my $mark = ($quote > 0) ? '&gt;' x $quote : ($pre > 0) ? ' ' : '';
		push(@result,$mark . $line);
	}
	return join("\n",@result);
}
sub _blocks { # ブロック要素
	# from YukiWiki http://www.hyuki.com/yukiwiki/
	# Copyright (C) 2000-2004 Hiroshi Yuki <hyuki@hyuki.com>
	my $text = shift;
	my (@result,@saved);
	my $heading = 0;
	my $quote_flag = 0;
	my @buf = split("\n",$text);
	unshift(@saved, '</p>');
	push(@result, '<p>');
	foreach (@buf) {
		if (/^(\*{1,3})(.+)/) { # 見出し
			my $number = (length($1) + LOWEST_HEADING - 1);
			$number = 6 if ($number > 6);
			my $hn = 'h' . $number;
			my $id = HEADING_PREFIX . $mEntryId . '-' . $heading;
			my $mark = HEADING_MARK;
			$mark = '<a href="#' . $id . '">' . $mark . '</a>' if ($mark ne '');
			push(@result, splice(@saved), qq(<$hn id="$id">$mark) . &_inline($2) . qq(</$hn>));
			$heading++;
		} elsif (/^----/) { # 水平線
			push(@result, splice(@saved), '<hr />');
		} elsif (/^#(.+)/ or /^\/\/(.+)/) { # 注釈文
			&_back_push(
				'tag'       => 'p',
				'level'     => 1,
				'saved'     => \@saved,
				'result'    => \@result,
				'attribute' => ' class="note"',
			);
			push(@result, &_inline($_) . '<br />');
		} elsif (/^(-{1,3})(.+)/) { # 箇条リスト
			&_back_push(
				'tag'       => 'ul',
				'level'     => length($1),
				'saved'     => \@saved,
				'result'    => \@result,
				'attribute' => '',
			);
			push(@result, '<li>' . &_inline($2) . '</li>');
		} elsif (/^(\+{1,3})(.+)/) { # 順列リスト
			&_back_push(
				'tag'       => 'ol',
				'level'     => length($1),
				'saved'     => \@saved,
				'result'    => \@result,
				'attribute' => '',
			);
			push(@result, '<li>' . &_inline($2) . '</li>');
		} elsif (/^:([^:]+):(.+)/) { # 定義リスト
			&_back_push(
				'tag'       => 'dl',
				'level'     => 1,
				'saved'     => \@saved,
				'result'    => \@result,
				'attribute' => '',
			);
			push(@result, '<dt>' . &_inline($1) . '</dt>', '<dd>' . &_inline($2) . '</dd>');
		} elsif (/^((&gt;){1,3})(.*)/) { # 引用ブロック
			my $attribute = '';
			my $level = length($1) / 4;
			my $quote = $3;
			if ($quote =~ /^=(.*?):(s?https?:\/\/[-_.!~*\'()a-zA-Z0-9;\/?:\@&=+\$,%#]+)?/) { # '
				$attribute .= ' title="' . $1 . '"' if ($1 ne '');
				$attribute .= ' cite="' . $2 . '"' if ($2 ne '');
			}
			&_back_push(
				'tag'       => 'blockquote',
				'level'     => $level,
				'saved'     => \@saved,
				'result'    => \@result,
				'attribute' => $attribute,
			);
			next if ($attribute ne '');
			push(@result, '<p>' . &_inline($quote) . '</p>'); # [0.09] changed
			# push(@result, ($quote ne '') ? &_inline($quote) . '<br />' : '</p><p>');
		} elsif (/^$/) { # 空行(パラグラフの終了)
			push(@result, splice(@saved));
			unshift(@saved, '</p>');
			push(@result, '<p>');
		} elsif (/^(\s)(.*)$/) { # 整形済みテキスト
			&_back_push(
				'tag'       => 'pre',
				'level'     => 1,
				'saved'     => \@saved,
				'result'    => \@result,
				'attribute' => '',
			);
			push(@result, $2);
		} elsif (/^\|(.*?)$/) { # 表組み
			my $tmp = $1;
			&_back_push(
				'tag'       => 'table',
				'level'     => 1,
				'saved'     => \@saved,
				'result'    => \@result,
				'attribute' => '',
			);
			my @elems = ($tmp =~ /(.*?)\|/g);
			my $value = '';
			foreach my $elem (@elems) {
				if ($elem =~ /^\*(.*)/) {
					$value .= '<th>' . $1 . '</th>'
				} else {
					$value .= '<td>' . $elem . '</td>';
				}
			}
			push(@result, '<tr>' . $value . '</tr>');
		} else { # 通常行
			push(@result, &_inline($_) . '<br />');
		}
	}
	push(@result, splice(@saved));
	return join("\n",@result);
}
sub _back_push { # ブロック配列処理
	# from YukiWiki http://www.hyuki.com/yukiwiki/
	# Copyright (C) 2000-2004 Hiroshi Yuki <hyuki@hyuki.com>
	my %param = (
		'tag'       => undef,
		'level'     => undef,
		'saved'     => undef,
		'result'    => undef,
		'attribute' => undef,
		@_
	);
	my $bgn_tag = '<' . $param{'tag'} . $param{'attribute'} . '>';
	my $end_tag = '</' . $param{'tag'} . '>';
	if ($param{'tag'} ne 'blockquote' and $param{'attribute'} ne '') {
		$param{'attribute'} =~ s/\-/_/g;
		$end_tag .= '<!--' . $param{'attribute'} . '-->';
	}
	while (@{$param{'saved'}} > $param{'level'}) {
		push(@{$param{'result'}}, shift(@{$param{'saved'}}));
	}
	if ($param{'saved'}->[0] ne $end_tag) {
		push(@{$param{'result'}}, splice(@{$param{'saved'}}));
	}
	while (@{$param{'saved'}} < $param{'level'}) {
		unshift(@{$param{'saved'}}, $end_tag);
		push(@{$param{'result'}}, $bgn_tag);
	}
}
sub _inline { # インライン要素
	my $text = shift; # 入出力パラメータ
	$text =~ s/''(.*?)''/<strong>$1<\/strong>/g;     # 強い強調 (Wiki表記)
	$text =~ s/\*\*(.*?)\*\*/<strong>$1<\/strong>/g; # 強い強調
	$text =~ s/\*(.*?)\*/<em>$1<\/em>/g;             # 弱い強調
	my $srvbase = sb::Config->get->value('conf_srv_base');
	my $srv_cgi = sb::Config->get->value('conf_srv_cgi');
	while ($text =~ /\^(.*?)\((.*?)\)/) { # ルビとリンク
		my $check = $2;
		if ($check =~ /(s?https?:\/\/[-_.!~*\'()a-zA-Z0-9;\/?:\@&=+\$,%#]+)/) { # '
			my $target = (index($check,$srvbase) > -1 or index($check,$srv_cgi) > -1) ? '' : LINK_TARGET;
			$text =~ s/\^(.*?)\((.*?)\)/<a href=\"$2\"$target>$1<\/a>/;
		} elsif ($check =~ /mailto:([\w=+\$%*-]+\@[^\s()\[\]{}!\"\'<>:,\x7f-\xff]+\.\w+)/) {
			$text =~ s/\^(.*?)\((.*?)\)/<a href=\"$2\">$1<\/a>/;
		} else {
			$text =~ s/\^(.*?)\((.*?)\)/<ruby><rb>$1<\/rb><rp>\(<\/rp><rt>$2<\/rt><rp>\)<\/rp><\/ruby>/;
		}
	}
	while ($text =~ /\[(.*?):(.*?)\]/) { # hatena, google, link
		my ($name,$check) = ($1,$2);
		if ($name ne '' and $check =~ /(s?https?:\/\/[-_.!~*\'()a-zA-Z0-9;\/?:\@&=+\$,%#]+)/) {  # '
			my $target = (index($check,$srvbase) > -1 or index($check,$srv_cgi) > -1) ? '' : LINK_TARGET;
			$text =~ s!\[(.*?):(.*?)\]!<a href="$2"$target>$name</a>!;
		} else {
			my $target = LINK_TARGET;
			my $amazon = LINK_AMAZON;
			my $hatena = LINK_HATENA;
			my $google = LINK_GOOGLE;
			if ($name =~ /ASIN/i and $check =~ /^\w+$/) { # Amazon
				$check = $amazon . $check . '/' . $self->{'amazon_id'};
				$text =~ s/\[(ASIN):(.*?)\]/<a href="$check"$target>$1:$2<\/a>/i;
			} elsif ($name =~ /keyword/i) { # keyword for Hatena
				$check = sb::Language->get->convert($check,'euc') if (sb::Language->get->charcode ne 'euc');
				$check =~ s/(\W)/'%' . unpack('H2', $1)/eg;
				$text =~ s/\[(.*?):(.*?)\]/<a href=\"$hatena$check\"$target>$2<\/a>/;
			} elsif ($name eq '' or $name =~ /google/i) { # word for Google
				$check = sb::Language->get->convert($check,'utf8') if (sb::Language->get->charcode ne 'utf8');
				$check =~ s/(\W)/'%' . unpack('H2', $1)/eg;
				$text =~ s/\[(.*?):(.*?)\]/<a href=\"$google$check\"$target>$2<\/a>/;
			} else { # escape blackets
				$text =~ s/\[(.*?):(.*?)\]/&sbf;$1\:$2\]/;
			}
		}
	}
	foreach my $tag ('img','hr','br') { # 単独要素
		while ($text =~ /\&lt;$tag (.*?)\&gt;/i) {
			my $attr = sb::Text->detitize($1);
			$text =~ s/\&lt;$tag (.*?)\&gt;/<$tag $attr>/i;
		}
	}
	foreach my $tag ('a','q','strong','em','abbr','code','p','div','del','ins') {
		while ($text =~ /\&lt;$tag(.*?)\&gt;(.+?)\&lt;\/$tag\&gt;/i) {
			my $attr = sb::Text->detitize($1);
			my $elem = $2;
			$text =~ s/\&lt;$tag(.*?)\&gt;(.+?)\&lt;\/$tag\&gt;/<$tag$attr>$elem<\/$tag>/i;
		}
	}
	if ($text =~ /(s?https?:\/\/[-_.!~*\'()a-zA-Z0-9;\/?:\@&=+\$,%#]+)/ and 
	    $text !~ /\"(s?https?:\/\/[-_.!~*\'()a-zA-Z0-9;\/?:\@&=+\$,%#]+)\"/) { # 文中 uri => http
		my $target = (index($1,$srvbase) > -1 or index($1,$srv_cgi) > -1) ? '' : LINK_TARGET;
		$text =~ s/(s?https?:\/\/[-_.!~*\'()a-zA-Z0-9;\/?:\@&=+\$,%#]+)/<a href=\"$1\"$target>$1<\/a>/g;
	}
	if ($text =~ /mailto:([\w=+\$%*-]+\@[^\s()\[\]{}!\"\'<>:,\x7f-\xff]+\.\w+)/ and 
	    $text !~ /\"mailto:([\w=+\$%*-]+\@[^\s()\[\]{}!\"\'<>:,\x7f-\xff]+\.\w+)\"/) { # 文中 uri => mailto
		$text =~ s/mailto:([\w=+\$%*-]+\@[^\s()\[\]{}!\"\'<>:,\x7f-\xff]+\.\w+)/<a href="mailto:$1">mailto:$1<\/a>/g;
	}
	return($text);
}
1;
__END__

==== sbtext 記法について ============================================
* ブロック要素
** 小見出し
「*」「**」「***」で始まる行を見出しとして扱います。

標準では「* => h2」「** => h3」「*** => h4」と扱われ、見出し用マーク
として「■」が利用されます。

** 引用ブロック
「>」で始まる行を引用ブロックとして扱います。

また、最初の引用行を
 >=title:http://serenebach.net/
のようにすると、引用ブロックの cite 属性、title 属性を記述できます。

「>>」と「<<」で囲まれた文章を引用ブロックとして扱います。

「>」と同様、
 >>=title:http://serenebach.net/
のようにすると、引用ブロックの cite 属性、title 属性を記述できます。

引用ブロックは3段までネスト可能です。「>>」は2段、「>>>」は3段の引用ブ
ロックとして扱われます。

** 注釈文
「#」ないし「//」で始まる行を注釈文として扱います(注釈文という要素はあ
りませんので、<p class="note"> としてマークアップされます)。

** 整形済みテキスト
スペース(タブないし半角スペース)で始まる行を整形済みテキストとして扱
います。

「>||」と「||<」で囲まれた文章を整形済みテキストとして扱います。

** 箇条リスト
「-」で始まる行を番号なしリスト(箇条リスト)として扱います。

「--」「---」のようにハイフンの数を増やすと、多段リストを表記できます。

** 順列リスト
「+」で始まる行を番号付きリスト(順列リスト)として扱います。

「++」「+++」のようにプラスの数を増やすと、多段リストを表記できます。

** 定義リスト
「:用語:説明文」のように記述すると、その行を定義リストとして扱います。

** 表組み
「|」で始まる行を表組みとして扱います。

 |*見出し1|*見出し2|
 |項目1|項目2|

「|*」と記述された項目は見出しセルとして扱います。

** 水平線
「----」で始まる行には水平線(<hr />)が挿入されます。

** 素の文
上記以外の素の文は p 要素として扱われます。

基本的に改行はそのまま改行として、扱われますので、ブロックを分けたい場
合は空行を入れるようにしてください。

----

* インライン要素
** 強調
「*」で囲まれた部分を強調として扱います。

「**」で囲まれた部分をより強い強調として扱います。

「''」で囲まれた部分をより強い強調として扱います。

** 自動リンク
本文中の url 文字列に自動的にリンクを張ります。標準では外部リンクには
target 属性が付加され、同一ウェブログ内のリンクには属性が付きません。

** イメージ
イメージタグは通常通り、<img> をそのまま利用できます。

** ルビ
「^ルビ(るび)」のように「^」で始まり、「(」と「)」で囲まれた部分を基
本的にルビとして扱います。「()」内が振り仮名になります。

ただし、振り仮名部分に url を記述していると「^」と「()」で挟まれた部
分をリンク文字列とするアンカーになります。

** 脚注
二重括弧「(())」で囲むと、囲まれた内容を脚注として末尾に追加されます。

脚注へのアンカーは自動的に連番で割り振られます。

** キーワードリンク
「[]」を利用した記述でキーワードリンクが利用できます。

- [keyword:語句]  : はてなの該当キーワードにリンクします。
- [:検索語句]     : Google の該当内容の検索結果ページにリンクします。
- [asin:ASIN番号] : Amazon.co.jpの該当商品ページにリンクします。
- [リンク名:url]  : URL にリンク名でリンクします。

** 特殊文字のエスケープ
「\」を利用すると、特殊文字をエスケープできます。

\*, \^, \<, \', \(, \[, \| があります。

例えば、二重括弧を脚注としてではなく通常の文章に利用したい場合、
 \((ここは脚注ではありません))
のように二重括弧の先頭に「\」を置くだけで普通の文章として利用できます。

* 参考資料他

このプラグインは以下のスクリプト・資料を参考させていただきました。

- [YukiWiki:http://www.hyuki.com/yukiwiki/]
-- Copyright (C) 2000-2004 Hiroshi Yuki <hyuki@hyuki.com>
- [はてなダイアリーヘルプ:http://d.hatena.ne.jp/help]
-- Copyright (C) 2002-2005 hatena.

