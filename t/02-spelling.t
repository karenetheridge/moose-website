#!perl
use 5.010;
use utf8;
use strict;
use warnings FATAL => 'all';
use autodie qw(:all);
use Capture::Tiny qw(capture);
use Encode qw(encode_utf8 decode_utf8);
use File::Next qw();
use File::Temp qw(tempfile);
use File::Which qw(which);
use Module::Build qw();
use Test::More;
use XML::LibXML qw();
use XML::LibXSLT qw();
use YAML::XS qw(Load);

binmode Test::More->builder->$_, ':encoding(UTF-8)'
    for qw(output failure_output todo_output);

# Skip means sweep bugs under the rug.
# I want this test to be actually run.
BAIL_OUT 'aspell is not installed.' unless which 'aspell';

my $build;
eval { $build = Module::Build->current; 1; }
  or BAIL_OUT 'We are not in a Module::Build session. Run Build.PL first.';

my $locale = $build->notes('locale');
my @stopwords;
{
    local $/ = undef;
    my $yaml = Load(encode_utf8(<DATA>));
    @stopwords = map {
        # kill scalar's IV NV or else the smart-match later will bomb out
        $_ eq 'Infinity' ? 'Infinity' : $_
    } @{ $yaml->{$locale} };
}

my $iter = File::Next::files({
        file_filter => sub {/\.html \z/msx},
        sort_files  => 1,
    },
    $build->destdir
);

my $file_counter;

my $stylesheet = XML::LibXSLT->new->parse_stylesheet(
    XML::LibXML->load_xml(string => <<""));
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xhtml="http://www.w3.org/1999/xhtml" version="1.0">
    <xsl:template match="xhtml:*[\@xml:lang!='$locale']"/>
    <xsl:template match="xhtml:abbr"/>
    <xsl:template match="xhtml:acronym"/>
    <xsl:template match="xhtml:code"/> <!-- filter computerese -->
    <xsl:template match="\@* | node()"> <!-- apply identity function to rest of nodes -->
        <xsl:copy>
            <xsl:apply-templates select="\@* | node()"/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>

while (defined(my $html_file = $iter->())) {
    $file_counter++;

    my ($temp_handle, $temp_file) = tempfile;
    my $transformed = $stylesheet->transform(XML::LibXML->load_xml(location => $html_file, load_ext_dtd => 0,));
    $stylesheet->output_fh($transformed, $temp_handle);

    my ($stdout) = capture {
        system "aspell -H --encoding=UTF-8 -l $locale list < $temp_file";
    };
    my @misspelt_words = grep {!($_ ~~ @stopwords)} split /\n/, decode_utf8 $stdout;
    ok !@misspelt_words, "$html_file ($temp_file) spell-check";
    diag join "\n", sort @misspelt_words if @misspelt_words;
}

done_testing($file_counter);

__DATA__
---
en:
## personal names
- Brocard
- Bunce's
# Pierce Cawley
- Cawley's
- Champoux
- chromatic
# Sam Crawley
- Crawley
- cuny's
- Doran
- franck
- Grünauer
- hakobe's
- hanekomu
- JT
- Hengst's
# Kanat-Alexander
- Kanat
- Kogman
- Kogman's
- Kuri's
- Lenz
- Léon
- Luehrs's
- Napiorkowski
- Pearcey's
- Perek's
- Prather
- Prather's
- Ragwitz
- Rockway
- Rodighiero
- Rolsky's
- SawyerX's
- Shlomi
- Stevan
- sunnavy's
- Treder's
- trombik
- Vecchi
- Vilain
- Vilain's
- Yanick
- Ynon
- Yuval

## proper names
- AirG
- BizRate
- CATH
- CLAB
- Cisco
- Cloudtone
- DoctorBase
- Endeworks
- FOSDEM
- GitHub
- Gource
- IMDb
# Kansai.pm
- Kansai
- Linkfluence
- LinuxMag
- Matsch
- MedTouch
- MusicBrainz
- OCaml
- Omni
- OnLAMP
- PerlMonks
- Pobox
- Shadowcat
- Shopzilla
- SimplyClick
- Simula
- SocialText
- Symantec
- Takkle
- Tamarou
- TextMate
- UNMC
- UNO
- ValueClick
- WebGUI

## Moose-specific

## computerese
- Parameterized
- parameterized

## other jargon

## neologisms
- Blog
- blog
- podcast

## compound
# post-mortem
- mortem
# PDX.pm
- PDX
# London.pm's
- pm's

## slang

## things that should be in the dictionary, but are not
- Bioinformatics
- Committers
- refactoring
- Refactoring

## single foreign words

## misspelt on purpose

de:

## Personennamen
- Apocalypse
- Austin
- Austins
- Barry
- Boones
- Brocard
- Bruno
- Bunce
- Cawleys
- Champoux
- Chris
- chromatic
- Cory
- Crawley
- cunys
- Dave
- Devin
- Doran
- Doug
- Drew
- Fish
- franck
- Grünauer
- hakobes
- hanekomu
- Hengsts
- Jay
- Jesse
- Jonathan
- JT
- Kanat
- Kogman
- Kogmans
- Kuri
- Larry
- Léon
- Luehrs
- Little
- Littles
- Marcel
- Moritz
- McLaughlin
- Mike
- Napiorkowski
- Ovid
- Ovids
- Pearceys
- Pereks
- Piers
- Prather
- Prathers
- Ragwitz
- Randal
- Rockway
- Rodighiero
- Rolsky
- Rolskys
- SawyerX
- Schwartz
- Shawn
- Shlomi
- Smith
- Stefano
- Stephens
- Stevan
- Stuart
- sunnavys
- Tomas
- Treders
- trombik
- Trout
- Vecchi
- Vilain
- Vilains
- Walsh
- Watsons
- Whitakers
- Yanick
- Ynon
- Yuval

## Eigennamen
- Beijing
- Catalyst
- Doodle
- Expanse
- FOSDEM
- Frozen
- Git
- GitHub
- Gource
- Houston
- Infinity
- Interactive
- Kansai
- Lacuna
- LinuxMag
- Melbourne
- Nashville
- Oasis
- OCaml
- OnLAMP
- Overflow
- PerlMonks
- Pittsburgh
- Ruby
- Simula
- TextMate
- WebGUI

## Moose-spezifisch
- Metaobjektprotokoll
- MOP
- Mouse
- parameterisierte
- Objektmetaprogrammierung

## Computerjargon
- Beispielcode
- Codewiederverwendung

## anderer Jargon
- Perlmonger
- Podcast

## Neologismen

## Verbundworte
# Duck-Typing
- Duck
- Typing
# Lese-Evaluierungs-Ausgabe-Schleife
- Evaluierungs
# 100%ig
- ig
# Perl.it
- it
# E-Lamp
- Lamp
# Meta-Moose
- Meta
# PDX.pm
- PDX
# Plug-In
- Plug
# diverse .pm
- pm
# RC-Dateien
- RC

## Umgangssprache

## nicht im Wörterbuch, aber sollte drin stehen
- Antiquierung
- Blog
- Blogeintrag
- Blogeinträge
- Datenkapselung
- Endbericht
- Expertenschulung
- Gemeinschaftsprojekt
- Gruppentreffen
- Hauptdistribution
- Hauptseite
- Hilfeangeboten
- nachzuschlagen
- Objektsystem
- Objektsystems
- Produktionseinsatz
- Proteinanalyse
- rollenbasierten
- Rollenzusammensetzung
- Schnellreferenzkarte
- Skriptoptionen
- Vortragsfolien
- Webansicht

## einzelne Fremdwörter
- Refactoring
- Repository
- Repositorys

## absichtlich falsch
