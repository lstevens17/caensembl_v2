=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

# $Id: HomePage.pm,v 1.69 2014-01-17 16:02:23 jk10 Exp $

package EnsEMBL::Web::Component::Info::HomePage;

use strict;

use EnsEMBL::Web::Document::HTML::HomeSearch;
use EnsEMBL::Web::DBSQL::ProductionAdaptor;
use EnsEMBL::Web::Component::GenomicAlignments;
use EnsEMBL::Web::Controller::SSI;
use EnsEMBL::Web::Document::Table;


use LWP::UserAgent;
use JSON;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub get_external_sources {
  my $self = shift;

  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;

  my $registry = $species_defs->FILE_REGISTRY_URL || return;

  my $species = $hub->species;
  my $taxid   = $species_defs->TAXONOMY_ID;
  return unless $taxid;

  my $url = $registry . '/restapi/resources?taxid=' . $taxid;
  my $ua  = LWP::UserAgent->new;

  my $response = $ua->get($url);
  if ($response->is_success) {
    if (my $sources = decode_json($response->content)) {
      if ($sources->{'total'}) {
        return $sources->{'sources'};
      }
    }
  }
}

sub external_sources {
  my $self = shift;

  my $sources = $self->get_external_sources;
  return unless $sources;

  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $html;

  my $table = $self->new_table([], [], {
    data_table        => 1,
    sorting           => ['id asc'],
    exportable        => 1,
    data_table_config => {
      iDisplayLength => 10
    },
#    hidden_columns => [1]
  });

  my @columns = (
    {
      key        => 'id',
      title      => 'Title',
      align      => 'left',
      sort       => 'string',
      priority   => 2147483647,    # Give transcriptid the highest priority as we want it to be the 1st colum
      display_id => '',
      link_text  => ''
    },
    {
      key        => 'desc',
      title      => 'Description',
      align      => 'left',
      sort       => 'string',
      priority   => 147483647,
      display_id => '',
      link_text  => ''
    },
    {
      key        => 'link',
      title      => 'Attach',
      display_id => '',
      link_text  => '',
      sort       => 'no'
    },
  );

  my @rows;

  my $sample_data = $species_defs->SAMPLE_DATA;
  my $region_url  = $species_defs->species_path . '/Location/View?r=' . $sample_data->{'LOCATION_PARAM'};

  foreach my $src (@$sources) {
    my $link = sprintf('<a target="extfiles" href="%s;contigviewbottom=url:%s"><img src="/i/96/region.png" style="height:16px" /></a>', $region_url, $src->{'url'});
    my $row = {
      id   => $src->{'title'},
      desc => $src->{'desc'},
      link => $link
    };
    push @rows, $row;
  }

  @columns = sort { $b->{'priority'} <=> $a->{'priority'} || $a->{'title'} cmp $b->{'title'} || $a->{'link_text'} cmp $b->{'link_text'} } @columns;
  $table->add_columns(@columns);
  $table->add_rows(@rows);

  $html .= '<h3>External resources</h3> <p> The following external datasets can be viewed in the browser. Just click on the attach icon to go to the location view.</p>' . $table->render;

  return $html;

}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $species      = $hub->species;
  my $img_url      = $self->img_url;
  my $common_name  = $species_defs->SPECIES_COMMON_NAME;
  my $dbs = $species_defs->get_config($species,'databases');
  my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -user   => $dbs->{'DATABASE_CORE'}{'USER'},
    -pass   => $dbs->{'DATABASE_CORE'}{'PASS'},
    -dbname => $dbs->{'DATABASE_CORE'}{'NAME'},
    -host   => $dbs->{'DATABASE_CORE'}{'HOST'},
    -port   => $dbs->{'DATABASE_CORE'}{'PORT'},
    -driver => 'mysql'
  );
  my $meta_container = $dba->get_adaptor("MetaContainer");
  my $production_name  = $species_defs->SPECIES_SCIENTIFIC_NAME.' '.$meta_container->single_value_by_key('assembly.name');
  $production_name =~ s/\s/_/g;
  my $display_name = $species_defs->SPECIES_SCIENTIFIC_NAME;
  my $taxid        = $species_defs->TAXONOMY_ID;
  my $sound        = $species_defs->SAMPLE_DATA->{'ENSEMBL_SOUND'};
  my $provider_link;

  if ($species_defs->PROVIDER_NAME && ref $species_defs->PROVIDER_NAME eq 'ARRAY') {
    my @providers;
    push @providers, map { $hub->make_link_tag(text => $species_defs->PROVIDER_NAME->[$_], url => $species_defs->PROVIDER_URL->[$_]) } 0 .. scalar @{$species_defs->PROVIDER_NAME} - 1;

    if (@providers) {
      $provider_link = join ', ', @providers;
      $provider_link .= ' | ';
    }
  }
  elsif ($species_defs->PROVIDER_NAME) {
    $provider_link = $hub->make_link_tag(text => $species_defs->PROVIDER_NAME, url => $species_defs->PROVIDER_URL) . " | ";
  }

###
# BEGIN LEPBASE MODIFICATION...

  my $html = '';

  my $about_text = $self->_other_text('about', $species);
  $html .= '<div class="column-wrapper lb-species-page"><div class="lb-column-one"><div class="lb-panel-container">';
  my $search_text = EnsEMBL::Web::Document::HTML::HomeSearch->new($hub)->render;

  my $species_info  = $hub->get_species_info;
  my $join = $species_defs->ASSEMBLY_STATS_URL =~ m/\?/ ? '' : '?';
  my $src = $species_defs->ASSEMBLY_STATS_URL.$join.'assembly='.$production_name.'&view=circle';
  my $altctr = 0;
  my $alt_asm_text;
  my %alt;
  my $relctr = 0;
  my $rel_asm_text;
  my $relalt = '';
  my $binomial = join(' ',(split /\s/,$species_defs->SPECIES_SCIENTIFIC_NAME)[0..1]);
  foreach (@{$hub->get_species_set('DEFAULT_FAVOURITES')}) {
    if ($species_info->{$_}->{'key'} ne $species_defs->SPECIES_URL){
      if ($species_info->{$_}->{'scientific'} eq $species_defs->SPECIES_SCIENTIFIC_NAME){
        $altctr++;
        my $asm = $species_info->{$_}->{'name'}.'_'.$species_info->{$_}->{'assembly'};
        $asm =~ s/\s/_/g;
        $alt_asm_text .= ' | ' if ($altctr > 1);
        $alt_asm_text .= '<a href="'.$species_info->{$_}->{'url'}.'">'.$species_info->{$_}->{'name'}.' '. $species_info->{$_}->{'assembly'}.'</a>';
        $alt{$species_info->{$_}->{'key'}} = 1;
        $src .= '&altAssembly='.$asm;
      }
      if (!$alt{$species_info->{$_}->{'key'}} && $binomial eq join(' ',(split /\s/,$species_info->{$_}->{'scientific'})[0..1])){
        $relctr++;
        my $asm = $species_info->{$_}->{'name'}.'_'.$species_info->{$_}->{'assembly'};
        $asm =~ s/\s/_/g;
        $alt{$species_info->{$_}->{'key'}} = 1;
        $rel_asm_text .= ' | ' if ($relctr > 1);
        $rel_asm_text .= '<a href="'.$species_info->{$_}->{'url'}.'">'.$species_info->{$_}->{'name'}.' '. $species_info->{$_}->{'assembly'}.'</a>';
        $relalt .= '&altAssembly='.$asm;
      }
    }
  }
  my $ref_asm = ucfirst $species_defs->REFERENCE_ASSEMBLY;
  if (!$alt{$species_info->{$ref_asm}->{'key'}} && $species_info->{$ref_asm}->{'key'} ne $species_defs->SPECIES_URL){
    my $asm = $species_info->{$ref_asm}->{'name'}.'_'.$species_info->{$ref_asm}->{'assembly'};
    $asm =~ s/\s/_/g;
    $relalt .= '&altAssembly='.$asm;
  }
  if ($altctr > 0){
    $src .= '&altView=compare';
    my $plural = $altctr > 1 ? 'assemblies' : 'assembly';
    $alt_asm_text = "<p>Alternate $plural available: ".$alt_asm_text.'</p>';
  }
  if ($relctr > 0){
    $src .= '&altView=compare' if $altctr == 0;
    my $plural = $relctr > 1 ? 'assemblies' : 'assembly';
    $rel_asm_text = "<p>Related $plural: ".$rel_asm_text.'</p>';
  }
  $src .= $relalt;
  $src .= '&altView=cumulative&altView=table';

  my $assembly_text = '<h3 class="lb-heading">Assembly statistics</h3><iframe class="lb-iframe" src="'.$src.'"></iframe>';
  $assembly_text .= '<p>Assembly stats plots are described at <a href="http://github.com/rjchallis/assembly-stats">github.com/rjchallis/assembly-stats</a>
  <br/><a href="https://zenodo.org/badge/latestdoi/20772/rjchallis/assembly-stats"><img src="https://zenodo.org/badge/20772/rjchallis/assembly-stats.svg" alt="10.5281/zenodo.56996" /></a>
  </p>';

  if ($about_text || $search_text || $alt_asm_text || $rel_asm_text) {
    $html .= '<div class="lb-info-box lb-species-page">';
    $html .= '<h3 class="lb-heading">About <em>'.$species_defs->SPECIES_SCIENTIFIC_NAME.'</em></h3>'.$about_text.'<br/>' if $about_text;
    $html .= $search_text if $search_text;
    $html .= $alt_asm_text if $alt_asm_text;
#    $html .= $rel_asm_text if $rel_asm_text;
    $html .= '<br/></div>';
  }

  $html .= '<div class="lb-info-box lb-species-page">'.$assembly_text.'</div>';

  # add meta table from database

  my $genebuild = 0;
  my $meta_text;
  my %meta;

  $meta{'provider'}{'name'} = $meta_container->single_value_by_key('provider.name');
  $meta{'provider'}{'url'} = $meta_container->single_value_by_key('provider.url');
  $meta{'species'}{'common_name'} = $meta_container->single_value_by_key('species.common_name');
  $meta{'species'}{'display_name'} = $meta_container->single_value_by_key('species.display_name');
  $meta{'species'}{'scientific_name'} = $meta_container->single_value_by_key('species.scientific_name');
  $meta{'species'}{'taxonomy_id'} = $meta_container->single_value_by_key('species.taxonomy_id');
  $meta{'assembly'}{'accession'} = $meta_container->single_value_by_key('assembly.accession');
  $meta{'assembly'}{'date'} = $meta_container->single_value_by_key('assembly.date');
  $meta{'assembly'}{'name'} = $meta_container->single_value_by_key('assembly.name');
  $meta{'assembly'}{'span'} = $meta_container->single_value_by_key('assembly.span');
  $meta{'assembly'}{'gc_percent'} = $meta_container->single_value_by_key('assembly.gc_percent');
  $meta{'assembly'}{'n'} = $meta_container->single_value_by_key('assembly.n');
  $meta{'assembly'}{'atgc'} = $meta_container->single_value_by_key('assembly.atgc');
  $meta{'assembly'}{'scaffold_count'} = $meta_container->single_value_by_key('assembly.scaffold_count');
  if ($meta_container->single_value_by_key('assembly.cegma_complete')){
    $meta{'assembly'}{'cegma_complete'} = $meta_container->single_value_by_key('assembly.cegma_complete');
    $meta{'assembly'}{'cegma_partial'} = $meta_container->single_value_by_key('assembly.cegma_partial');
  }
  if ($meta_container->single_value_by_key('assembly.busco_complete')){
    $meta{'assembly'}{'busco_complete'} = $meta_container->single_value_by_key('assembly.busco_complete');
    $meta{'assembly'}{'busco_duplicated'} = $meta_container->single_value_by_key('assembly.busco_duplicated');
    $meta{'assembly'}{'busco_fragmented'} = $meta_container->single_value_by_key('assembly.busco_fragmented');
    $meta{'assembly'}{'busco_missing'} = $meta_container->single_value_by_key('assembly.busco_missing');
    $meta{'assembly'}{'busco_number'} = $meta_container->single_value_by_key('assembly.busco_number');
  }
  $meta{'genebuild'}{'method'} = $meta_container->single_value_by_key('genebuild.method');
  $meta{'genebuild'}{'start_date'} = $meta_container->single_value_by_key('genebuild.start_date');
  $meta{'genebuild'}{'version'} = $meta_container->single_value_by_key('genebuild.version');
  $meta{'genebuild'}{'gene_count'} = $meta_container->single_value_by_key('genebuild.gene_count');
  $meta{'genebuild'}{'transcript_count'} = $meta_container->single_value_by_key('genebuild.transcript_count');
  $meta{'genebuild'}{'cds_count'} = $meta_container->single_value_by_key('genebuild.cds_count');
  $meta{'genebuild'}{'exon_count'} = $meta_container->single_value_by_key('genebuild.exon_count');



  my $p = \%meta;
  my @order = qw(provider species assembly);
  if ($p->{'genebuild'}{'gene_count'}){
    push @order,'genebuild';
    $genebuild = 1;
  }
  my %order = ( 'provider' => ['name', 'url'],
                'species' => ['scientific_name', 'taxonomy_id', 'common_name', 'display_name'],
                'assembly' => ['name', 'accession', 'date', 'span', 'atgc', 'n', 'gc_percent', 'scaffold_count'],
                'genebuild' => ['version', 'method', 'start_date', 'gene_count', 'transcript_count', 'cds_count', 'exon_count']);
  my $table = '<table class="lb-meta-table">';
  while (my $group = shift @order){
    next unless $p->{$group};
    my $i = 0;
    my %added;
    foreach my $key (@{$order{$group}}){
      my $g = $i == 0 ? ucfirst $group : '';
      my $k = $key;
      $k =~ s/_/ /g;
      my $value = $p->{$group}{$key};
      next unless $value;
      if ($key eq 'url'){
        $value = '<a href="value">'.$value.'</a>'
      }
      $table .= '<tr><td class="lb-meta-group">'.$g.'</td><td class="lb-meta-key">'.$k.'</td><td class="lb-meta-value">'.$value.'</td></tr>';
      $added{$key}++;
      $i++;
    }
    foreach my $key (sort keys %{$p->{$group}}){
      next if $added{$key};
      my $g = $i == 0 ? ucfirst $group : '';
      my $k = $key;
      $k =~ s/_/ /g;
      my $value = $p->{$group}{$key};
      if ($key eq 'url'){
        $value = '<a href="value">'.$value.'</a>'
      }
      $table .= '<tr><td class="lb-meta-group">'.$g.'</td><td class="lb-meta-key">'.$k.'</td><td class="lb-meta-value">'.$value.'</td></tr>';
      $i++;
    }
  }
  $table .= '</table>';

  $meta_text = '<h3 class="lb-heading">Assembly metadata</h3><p/>'.$table;


  my $extra_text = $self->_other_text('assembly', $species);
  $extra_text .= $self->_other_text('annotation', $species);
  $extra_text .= $self->_other_text('references', $species);

  if ($genebuild == 1){
    $html .= '<div class="lb-info-box lb-species-page"><h3 class="lb-heading">More information</h3>'.$extra_text.'</div>';
  }

  $html .= '</div><div class="lb-panel-container">';


  if ($genebuild == 1){
    $join = $species_defs->CODON_USAGE_URL =~ m/\?/ ? '' : '?';
    $src = $species_defs->CODON_USAGE_URL.$join.'assembly='.$production_name.'&view=plot&altView=table';
#    if ($alternate{$production_name}){
#      $src .= '&altAssembly='.$alternate{$production_name}->[0];
#    }
    my $codon_text = '<h3 class="lb-heading">Codon usage</h3><iframe class="lb-iframe" src="'.$src.'"></iframe>';
    $codon_text .= '<p>Codon usage plots are described at <a href="http://github.com/rjchallis/codon-usage">github.com/rjchallis/codon-usage</a>
    <br/><a href="https://zenodo.org/badge/latestdoi/20772/rjchallis/codon-usage"><img src="https://zenodo.org/badge/20772/rjchallis/codon-usage.svg" alt="10.5281/zenodo.56681" /></a>
    </p>';

    $html .= '<div class="lb-info-box lb-species-page">'.$codon_text.'</div>';
  }

  $html .= '<div class="lb-info-box lb-species-page">'.$meta_text.'</div>';

  if ($genebuild == 0){
    $html .= '<div class="lb-info-box lb-species-page"><h3 class="lb-heading">More information</h3>'.$extra_text.'</div>';
  }

#  if ($self->has_compara or $self->has_pan_compara) {
###
# comment out for initial lepbase release
#    push(@sections, $self->_compara_text);
###
 #  $html .= '<div class="' . $box_class[$side % 2] . '"><div class="round-box tinted-box unbordered">' . $self->_compara_text . '</div></div>';
 #  $side++;

###
# comment out for initial lepbase release
#  push(@sections, $self->_variation_text);
###
 #$html .= '<div class="' . $box_class[$side % 2] . '"><div class="round-box tinted-box unbordered">' . $self->_variation_text . '</div></div>';
 #$side++;

#  if ($hub->database('funcgen')) {
#    push(@sections, $self->_funcgen_text);
  # $html .= '<div class="' . $box_class[$side % 2] . '"><div class="round-box tinted-box unbordered">' . $self->_funcgen_text . '</div></div>';
  # $side++;
#  }

#  my @box_class = ('box-left', 'box-right');
#  my $side = 0;
#  foreach my $section (@sections){


#  }



  $html .= '</div></div></div>';

# ...END LEPBASE MODIFICATION
###

  my $ext_source_html = $self->external_sources;
  $html .= '<div class="column-wrapper"><div class="round-box tinted-box unbordered">' . $ext_source_html . '</div></div>' if $ext_source_html;

  return $html;
}

sub _whatsnew_text {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $species      = $hub->species;
  my $news_url     = $hub->url({'action' => 'WhatsNew'});

  my $html = sprintf(qq(<h2><a href="%s" title="More release news"><img src="%s24/announcement.png" style="vertical-align:middle" alt="" /></a> What's New in %s release %s</h2>), $news_url, $self->img_url, $species_defs->SPECIES_COMMON_NAME, $species_defs->ENSEMBL_VERSION,);

  if ($species_defs->multidb->{'DATABASE_PRODUCTION'}{'NAME'}) {
    my $adaptor = EnsEMBL::Web::DBSQL::ProductionAdaptor->new($hub);
    my $params  = {'release' => $species_defs->ENSEMBL_VERSION, 'species' => $species, 'limit' => 3};
    my @changes = @{$adaptor->fetch_changelog($params)};

    $html .= '<ul>';

    foreach my $record (@changes) {
      my $record_url = $news_url . '#change_' . $record->{'id'};
      $html .= sprintf('<li><a href="%s" class="nodeco">%s</a></li>', $record_url, $record->{'title'});
    }
    $html .= '</ul>';
  }

  return $html;
}

sub _site_release {
  my $self = shift;
  return $self->hub->species_defs->SITE_RELEASE_VERSION;
}

sub _assembly_text {
  my $self             = shift;
  my $hub              = $self->hub;
  my $species_defs     = $hub->species_defs;
  my $species          = $hub->species;
  my $name             = $species_defs->SPECIES_COMMON_NAME;
  my $img_url          = $self->img_url;
  my $sample_data      = $species_defs->SAMPLE_DATA;
  my $ensembl_version  = $self->_site_release;
  my $current_assembly = $species_defs->ASSEMBLY_NAME;
  my $accession        = $species_defs->ASSEMBLY_ACCESSION;
  my $source           = $species_defs->ASSEMBLY_ACCESSION_SOURCE || 'NCBI';
  my $source_type      = $species_defs->ASSEMBLY_ACCESSION_TYPE;
 #my %archive          = %{$species_defs->get_config($species, 'ENSEMBL_ARCHIVES') || {}};
  my %assemblies       = %{$species_defs->get_config($species, 'ASSEMBLIES') || {}};
  my $previous         = $current_assembly;

  my $html = '<div class="homepage-icon">';

  if (@{$species_defs->ENSEMBL_CHROMOSOMES || []}) {
    $html .= qq(<a class="nodeco _ht" href="/$species/Location/Genome" title="Go to $name karyotype"><img src="${img_url}96/karyotype.png" class="bordered" /><span>View karyotype</span></a>);
  }

  my $region_text = $sample_data->{'LOCATION_TEXT'};
  my $region_url  = $species_defs->species_path . '/Location/View?r=' . $sample_data->{'LOCATION_PARAM'};

  $html .= qq(<a class="nodeco _ht" href="$region_url" title="Go to $region_text"><img src="${img_url}96/region.png" class="bordered" /><span>Example region</span></a>);
  $html .= '</div>'; #homepage-icon

  my $assembly = $current_assembly;
  if ($accession) {
    $assembly = $hub->get_ExtURL_link($current_assembly, 'ENA', $accession);
  }
  $html .= "<h2>Genome assembly: $assembly</h2>";
  $html .= qq(<p><a href="/$species/Info/Annotation/#assembly" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />More information and statistics</a></p>);

  # Link to FTP site
  if ($species_defs->ENSEMBL_FTP_URL) {
    my $ftp_url;
    if ($self->is_bacteria) {
      $ftp_url = sprintf '%s/release-%s/fasta/%s_collection/%s/dna/', $species_defs->ENSEMBL_FTP_URL, $ensembl_version, $species_defs->SPECIES_DATASET, lc $species;
    }
    else {
      $ftp_url = sprintf '%s/release-%s/fasta/%s/dna/', $species_defs->ENSEMBL_FTP_URL, $ensembl_version, lc $species;
    }
###
# comment out for initial lepbase release
#    $html .= qq(<p><a href="$ftp_url" class="nodeco"><img src="${img_url}24/download.png" alt="" class="homepage-link" />Download DNA sequence</a> (FASTA)</p>);
###
  }

  # Link to assembly mapper
  my $mappings = $species_defs->ASSEMBLY_MAPPINGS;
  if ($mappings && ref($mappings) eq 'ARRAY') {
    my $am_url = $hub->url({'type' => 'UserData', 'action' => 'SelectFeatures'});
    $html .= qq(<p><a href="$am_url" class="modal_link nodeco"><img src="${img_url}24/tool.png" class="homepage-link" />Convert your data to $assembly coordinates</a></p>);
  }

###
# comment out for initial lepbase release
#  $html .= sprintf '<p><a href="%s" class="nodeco" rel="modal_user_data">%sDisplay your data in %s</a></p>',
#    $hub->url({ type => 'UserData', action => 'SelectFile', __clear => 1 }), qq|<img src="${img_url}24/page-user.png" class="homepage-link" />|, $species_defs->ENSEMBL_SITETYPE;
###

#EG no old assemblies
 ## PREVIOUS ASSEMBLIES
 #my @old_archives;
 #
 ## Insert dropdown list of old assemblies
 #foreach my $release (reverse sort keys %archive) {
 #  next if $release == $ensembl_version;
 #  next if $assemblies{$release} eq $previous;

 #  push @old_archives, {
 #    url      => sprintf('http://%s.archive.ensembl.org/%s/', lc $archive{$release},           $species),
 #    assembly => "$assemblies{$release}",
 #    release  => (sprintf '(%s release %s)',                  $species_defs->ENSEMBL_SITETYPE, $release),
 #  };

 #  $previous = $assemblies{$release};
 #}

 ## Combine archives and pre
 #my $other_assemblies;
 #if (@old_archives) {
 #  $other_assemblies .= join '', map qq(<li><a href="$_->{'url'}" class="nodeco">$_->{'assembly'}</a> $_->{'release'}</li>), @old_archives;
 #}

 #my $pre_species = $species_defs->get_config('MULTI', 'PRE_SPECIES');
 #if ($pre_species->{$species}) {
 #  $other_assemblies .= sprintf('<li><a href="http://pre.ensembl.org/%s/" class="nodeco">%s</a> (Ensembl pre)</li>', $species, $pre_species->{$species}[1]);
 #}

 #if ($other_assemblies) {
 #  $html .= qq(
 #    <h3 style="color:#808080;padding-top:8px">Other assemblies</h3>
 #    <ul>$other_assemblies</ul>
 #  );
 #}

  return $html;
}

sub _genebuild_text {
  my $self            = shift;
  my $hub             = $self->hub;
  my $species_defs    = $hub->species_defs;
  my $species         = $hub->species;
  my $img_url         = $self->img_url;
  my $sample_data     = $species_defs->SAMPLE_DATA;
  my $ensembl_version = $self->_site_release;
  my $vega            = $species_defs->get_config('MULTI', 'ENSEMBL_VEGA');
  my $has_vega        = $vega->{$species};

  my $html = '<div class="homepage-icon">';

  my $gene_text = $sample_data->{'GENE_TEXT'};
  my $gene_url  = $species_defs->species_path . '/Gene/Summary?g=' . $sample_data->{'GENE_PARAM'};
  $html .= qq(<a class="nodeco _ht" href="$gene_url" title="Go to gene $gene_text"><img src="${img_url}96/gene.png" class="bordered" /><span>Example gene</span></a>);

  my $trans_text = $sample_data->{'TRANSCRIPT_TEXT'};
  my $trans_url  = $species_defs->species_path . '/Transcript/Summary?t=' . $sample_data->{'TRANSCRIPT_PARAM'};
  $html .= qq(<a class="nodeco _ht" href="$trans_url" title="Go to transcript $trans_text"><img src="${img_url}96/transcript.png" class="bordered" /><span>Example transcript</span></a>);

  $html .= '</div>'; #homepage-icon

  $html .= '<h2>Gene annotation</h2><p><strong>What can I find?</strong> Protein-coding and non-coding genes, splice variants, cDNA and protein sequences, non-coding RNAs.</p>';
  $html .= qq(<p><a href="/$species/Info/Annotation/#genebuild" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />More about this genebuild</a></p>);

  if ($species_defs->ENSEMBL_FTP_URL) {
    my $fasta_url = $hub->get_ExtURL('SPECIES_FTP_URL',{GENOMIC_UNIT=>$species_defs->GENOMIC_UNIT,VERSION=>$ensembl_version, FORMAT=>'fasta', SPECIES=> $self->is_bacteria ? $species_defs->SPECIES_DATASET . "_collection/" . lc $species : lc $species},{class=>'nodeco'});
    my $gff3_url  = $hub->get_ExtURL('SPECIES_FTP_URL',{GENOMIC_UNIT=>$species_defs->GENOMIC_UNIT,VERSION=>$ensembl_version, FORMAT=>'gff3', SPECIES=> $self->is_bacteria ? $species_defs->SPECIES_DATASET . "_collection/" . lc $species : lc $species},{class=>'nodeco'});
###
# comment out for initial lepbase release
#    $html .= qq[<p><img src="${img_url}24/download.png" alt="" class="homepage-link" />Download genes, cDNAs, ncRNA, proteins - <span class="center"><a href="$fasta_url" class="nodeco">FASTA</a> - <a href="$gff3_url" class="nodeco">GFF3</a></span></p>];
###
  }

###
# comment out for initial lepbase release
#  my $im_url = $hub->url({'type' => 'UserData', 'action' => 'UploadStableIDs'});
#  $html .= qq(<p><a href="$im_url" class="modal_link nodeco"><img src="${img_url}24/tool.png" class="homepage-link" />Update your old Ensembl IDs</a></p>);
###

  if ($has_vega) {
    $html .= qq(
      <a href="http://vega.sanger.ac.uk/$species/" class="nodeco">
      <img src="/img/vega_small.gif" alt="Vega logo" style="float:left;margin-right:8px;width:83px;height:30px;vertical-align:center" title="Vega - Vertebrate Genome Annotation database" /></a>
      <p>
        Additional manual annotation can be found in <a href="http://vega.sanger.ac.uk/$species/" class="nodeco">Vega</a>
      </p>
    );
  }

  return $html;
}

sub _compara_text {
  my $self            = shift;
  my $hub             = $self->hub;
  my $species_defs    = $hub->species_defs;
  my $species         = $hub->species;
  my $img_url         = $self->img_url;
  my $sample_data     = $species_defs->SAMPLE_DATA;
  my $ensembl_version = $species_defs->SITE_RELEASE_VERSION;

  my $html = '<div class="homepage-icon">';

  my $tree_text = $sample_data->{'GENE_TEXT'};
  my $tree_url  = $species_defs->species_path . '/Gene/Compara_Tree?g=' . $sample_data->{'GENE_PARAM'};

  # EG genetree
  $html .= qq(
    <a class="nodeco _ht" href="$tree_url" title="Go to gene tree for $tree_text"><img src="${img_url}96/compara.png" class="bordered" /><span>Example gene tree</span></a>
  ) if $self->has_compara('GeneTree');

  # EG family
  if ($self->is_bacteria) {

    $tree_url = $species_defs->species_path . '/Gene/Gene_families?g=' . $sample_data->{'GENE_PARAM'};
    $html .= qq(
      <a class="nodeco _ht" href="$tree_url" title="Go to gene families for $tree_text"><img src="${img_url}96/gene_families.png" class="bordered" /><span>Gene families</span></a>
    ) if $self->has_compara('Family');

  }
  else {

    $tree_url = $species_defs->species_path . '/Gene/Family?g=' . $sample_data->{'GENE_PARAM'};
    $html .= qq(
      <a class="nodeco _ht" href="$tree_url" title="Go to protein families for $tree_text"><span>Protein families</span></a>
    ) if $self->has_compara('Family');

  }

  # EG pan tree
  $tree_url = $species_defs->species_path . '/Gene/Compara_Tree/pan_compara?g=' . $sample_data->{'GENE_PARAM'};
  if ($self->has_pan_compara('GeneTree')) {
    $html .=
      $self->is_bacteria
      ? qq(<a class="nodeco _ht" href="$tree_url" title="Go to pan-taxonomic gene tree for $tree_text"><img src="${img_url}96/compara.png" class="bordered" /><span>Pan-taxonomic tree</span></a>)
      : qq(<a class="nodeco _ht" href="$tree_url" title="Go to pan-taxonomic gene tree for $tree_text"><span>Pan-taxonomic tree</span></a>);
  }

  # EG pan family
  $tree_url = $species_defs->species_path . '/Gene/Family/pan_compara?g=' . $sample_data->{'GENE_PARAM'};
  $html .= qq(
    <a class="nodeco _ht" href="$tree_url" title="Go to pan-taxonomic protein families for $tree_text"><span>Pan-taxonomic protein families</span></a>
  ) if $self->has_pan_compara('Family');

  # /EG
  $html .= '</div>';

  $html .= '<h2>Comparative genomics</h2>';

  if ($self->is_bacteria) {
    $html .= '<p><strong>What can I find?</strong> ';
    $html .= 'Gene families based on HAMAP and PANTHER classification.</p>'                if $self->has_compara;
    $html .= 'Homologues and gene trees including species across the pan-taxonomic range.' if $self->has_pan_compara;
    $html .= '</p>';
  }
  else {
    $html .= '<p><strong>What can I find?</strong>  Homologues, gene trees, and whole genome alignments across multiple species.</p>';
  }
  $html .= qq(<p><a href="http://ensemblgenomes.org/info/data/whole_genome_alignment" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />More about comparative analysis</a></p>);

  if ($species_defs->ENSEMBL_FTP_URL) {
    my $ftp_url = sprintf '%s/release-%s/emf/ensembl-compara/', $species_defs->ENSEMBL_FTP_URL, $ensembl_version;
    $html .= qq(<p><a href="$ftp_url" class="nodeco"><img src="${img_url}24/download.png" alt="" class="homepage-link" />Download alignments</a> (EMF)</p>)
      unless $self->is_bacteria;
  }
  my $aligns = EnsEMBL::Web::Component::GenomicAlignments->new($hub)->content;
  if ($aligns) {
    $html .= sprintf(qq{<p><div class="js_panel"><img src="%s24/info.png" alt="" class="homepage-link" />Genomic alignments [%s]</div></p>}, $img_url, $aligns);
  }
  return $html;
}

sub _variation_text {
  my $self         = shift;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $species      = $hub->species;
  my $img_url      = $self->img_url;
  my $sample_data  = $species_defs->SAMPLE_DATA;
  my $ensembl_version = $species_defs->SITE_RELEASE_VERSION;
  my $display_name    = $species_defs->SPECIES_SCIENTIFIC_NAME;
  my $html;

  if ($hub->database('variation')) {
    $html .= '<div class="homepage-icon">';

    if ($sample_data->{'VARIATION_PARAM'}) {
      my $var_url  = $species_defs->species_path . '/Variation/Explore?v=' . $sample_data->{'VARIATION_PARAM'};
      my $var_text = $sample_data->{'VARIATION_TEXT'};
      $html .= qq(
        <a class="nodeco _ht" href="$var_url" title="Go to variant $var_text"><img src="${img_url}96/variation.png" class="bordered" /><span>Example variant</span></a>
      );
    }

    if ($sample_data->{'PHENOTYPE_PARAM'}) {
      my $phen_text = $sample_data->{'PHENOTYPE_TEXT'};
      my $phen_url  = $species_defs->species_path . '/Phenotype/Locations?ph=' . $sample_data->{'PHENOTYPE_PARAM'};
      $html .= qq(<a class="nodeco _ht" href="$phen_url" title="Go to phenotype $phen_text"><img src="${img_url}96/phenotype.png" class="bordered" /><span>Example phenotype</span></a>);
    }

    if ($sample_data->{'STRUCTURAL_PARAM'}) {
      my $struct_text = $sample_data->{'STRUCTURAL_TEXT'};
      my $struct_url = $species_defs->species_path .'/StructuralVariation/Explore?sv='.$sample_data->{'STRUCTURAL_PARAM'};
      $html .= qq(<a class="nodeco _ht"  href="$struct_url" title="Go to structural variant $struct_text"><img src="${img_url}96/struct_var.png" class="bordered" /><span>Example structural variant</span></a>);
    }

    $html .= '</div>';
    $html .= '<h2>Variation</h2><p><strong>What can I find?</strong> Short sequence variants';
    if ($species_defs->databases->{'DATABASE_VARIATION'}{'STRUCTURAL_VARIANT_COUNT'}) {
      $html .= ' and longer structural variants';
    }
    if ($sample_data->{'PHENOTYPE_PARAM'}) {
      $html .= '; disease and other phenotypes';
    }
    $html .= '.</p>';

    if ($self->_other_text('variation', $species)) {
      $html .= qq(<p><a href="/$species/Info/Annotation#variation" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />More about variation in $display_name</a></p>);
    }

    my $site = $species_defs->ENSEMBL_SITETYPE;
    $html .= qq(<p><a href="http://ensemblgenomes.org/info/data/variation" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />More about variation in $site</a></p>);

    if ($species_defs->ENSEMBL_FTP_URL) {
      my @links;
      foreach my $format (qw/gvf vcf/){
        push(@links, sprintf('<a href="%s/release-%s/%s/%s/" class="nodeco _ht" title="Download (via FTP) all <em>%s</em> variants in %s format">%s</a>', $species_defs->ENSEMBL_FTP_URL, $ensembl_version, $format, lc $species, $display_name, uc $format,uc $format));
      }
      push(@links, sprintf('<a href="%s/release-%s/vep/%s_vep_%s.tar.gz" class="nodeco _ht" title="Download (via FTP) all <em>%s</em> variants in VEP format">VEP</a>', $species_defs->ENSEMBL_FTP_URL, $ensembl_version, lc $species, $ensembl_version, $display_name));
      my $links = join(" - ", @links);
      $html .= qq[<p><img src="${img_url}24/download.png" alt="" class="homepage-link" />Download all variants - $links</p>];
    }
  }
  else {
    $html .= '<h2>Variation</h2><p>This species currently has no variation database. However you can process your own variants using the Variant Effect Predictor:</p>';
  }

  my $vep_url = $hub->url({'type' => 'UserData', 'action' => 'UploadVariations'});
  $html .= qq(<p><a href="$vep_url" class="modal_link nodeco"><img src="${img_url}24/tool.png" class="homepage-link" />Variant Effect Predictor<img src="${img_url}vep_logo_sm.png" style="vertical-align:top;margin-left:12px" /></a></p>);

  return $html;
}

sub _funcgen_text {
  my $self            = shift;
  my $hub             = $self->hub;
  my $species_defs    = $hub->species_defs;
  my $species         = $hub->species;
  my $img_url         = $self->img_url;
  my $sample_data     = $species_defs->SAMPLE_DATA;
  my $ensembl_version = $species_defs->ENSEMBL_VERSION;
  my $site            = $species_defs->ENSEMBL_SITETYPE;
  my $html;

  my $sample_data = $species_defs->SAMPLE_DATA;
  if ($sample_data->{'REGULATION_PARAM'}) {
    $html = '<div class="homepage-icon">';

    my $reg_url  = $species_defs->species_path . '/Regulation/Cell_line?db=funcgen;rf=' . $sample_data->{'REGULATION_PARAM'};
    my $reg_text = $sample_data->{'REGULATION_TEXT'};
    $html .= qq(<a class="nodeco _ht" href="$reg_url" title="Go to regulatory feature $reg_text"><img src="${img_url}96/regulation.png" class="bordered" /><span>Example regulatory feature</span></a>);
    $html .= '</div>';
    $html .= '<h2>Regulation</h2><p><strong>What can I find?</strong> DNA methylation, transcription factor binding sites, histone modifications, and regulatory features such as enhancers and repressors, and microarray annotations.</p>';

    # EG add a link to about_[spp]#regulation
    my $display_name = $species_defs->SPECIES_SCIENTIFIC_NAME;
    if ($self->_other_text('regulation', $species)) {
      $html .= qq(<p><a href="/$species/Info/Annotation#regulation" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />More about regulation in $display_name</a></p>);
    }

    $html .= qq(<p><a href="/info/docs/funcgen/" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />More about the $site regulatory build</a> and <a href="/info/docs/microarray_probe_set_mapping.html" class="nodeco">microarray annotation</a></p>);

    if ($species_defs->ENSEMBL_FTP_URL) {
      my $ftp_url = sprintf '%s/release-%s/regulation/%s/', $species_defs->ENSEMBL_FTP_URL, $ensembl_version, lc $species;
      $html .= qq(<p><a href="$ftp_url" class="nodeco"><img src="${img_url}24/download.png" alt="" class="homepage-link" />Download all regulatory features</a> (GFF)</p>);
    }
  }
  else {
    $html .= '<h2>Regulation</h2><p><strong>What can I find?</strong> Microarray annotations.</p>';

    # EG add a link to about_[spp]#regulation
    my $display_name = $species_defs->SPECIES_SCIENTIFIC_NAME;
    if ($self->_other_text('regulation', $species)) {
      $html .= qq(<p><a href="/$species/Info/Annotation#regulation" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />More about regulation in $display_name</a></p>);
    }
    $html .= qq(<p><a href="http://ensemblgenomes.org/info/data/microarray_mapping" class="nodeco"><img src="${img_url}24/info.png" alt="" class="homepage-link" />More about the $site microarray annotation strategy</a></p>);

  }

  return $html;
}

# EG

=head2 _other_text

  Arg[1] : tag name to seek
  Arg[2] : species internal name e.g. Caenorhabditis_elegans
  Return : text from htdocs/ssi/species/about_[species].html bounded by the string: <!-- {tag} -->

=cut

sub _other_text {
  my ($self, $tag, $species) = @_;
  my $file = "/ssi/species/about_${species}.html";
  my $content = EnsEMBL::Web::Controller::SSI::template_INCLUDE($self, $file);
  my ($other_text) = $content =~ /^.*?<!--\s*\{$tag\}\s*-->(.*)<!--\s*\{$tag\}\s*-->.*$/ms;
  #ENSEMBL-2535 strip subs
  $other_text =~ s/(\{\{sub_[^\}]*\}\})//mg;
  return $other_text;
}

=head2 _has_compara

  Arg[1]     : Database to check, 'compara' or 'compara_pan_ensembl'
  Arg[2]     : Optional - Type of object to check for, e.g. GeneTree, Family
  Description: Check for existence of Compara data for the sample gene
  Returns    : 0, 1, or number of objects

=cut

sub _has_compara {
  my $self           = shift;
  my $db_name        = shift || 'compara';
  my $object_type    = shift;
  my $hub            = $self->hub;
  my $species_defs   = $hub->species_defs;
  my $sample_gene_id = $species_defs->SAMPLE_DATA->{'GENE_PARAM'};
  my $db             = $hub->database($db_name);
  my $has_compara    = 0;

  if ($db) {
    if ($object_type) {
      if ($sample_gene_id) {
        # check existence of a specific data type for the sample gene
        my $member_adaptor = $db->get_GeneMemberAdaptor;
        my $object_adaptor = $db->get_adaptor($object_type);

        if (my $member = $member_adaptor->fetch_by_stable_id($sample_gene_id)) {
          if ($object_type eq 'Family' and $self->is_bacteria) {
            $member = $member->get_all_SeqMembers->[0];
          }
          my $objects = $object_adaptor->fetch_all_by_Member($member);
          $has_compara = @$objects;
        }
      }
    } else {
      # no object type specified, simply check if this species is in the db
      my $genome_db_adaptor = $db->get_GenomeDBAdaptor;
      my $genome_db;
      eval{
        $genome_db = $genome_db_adaptor->fetch_by_registry_name($hub->species);
      };
      $has_compara = $genome_db ? 1 : 0;
    }
  }

  return $has_compara;
}

# shortcuts
sub has_compara     {
  my $self = shift;
  return $self->_has_compara('compara', @_);
}

sub has_pan_compara     {
  my $self = shift;
  return $self->_has_compara('compara_pan_ensembl', @_);
}

sub is_bacteria {
  my $self = shift;
  if (!defined $self->{_is_bacteria}) {
    $self->{_is_bacteria} = $self->hub->species_defs->GENOMIC_UNIT =~ /bacteria/i ? 1 : 0;
  }
  return $self->{_is_bacteria};
}

# /EG

1;
