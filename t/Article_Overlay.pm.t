#!/usr/bin/perl -w

use Test::More 'no_plan';

use_ok(RT);
RT::LoadConfig();
RT::Init();

use_ok(RT::FM::Article);
use_ok(RT::FM::ArticleCollection);
use_ok(RT::FM::Class);

my $user = RT::CurrentUser->new('root');

my $class = RT::FM::Class->new($user);


my ($id, $msg) = $class->Create(Name =>'ArticleTest');
ok ($id, $msg);



my $article = RT::FM::Article->new($user);
ok (UNIVERSAL::isa($article, 'RT::FM::Article'));
ok (UNIVERSAL::isa($article, 'RT::FM::Record'));
ok (UNIVERSAL::isa($article, 'RT::Record'));
ok (UNIVERSAL::isa($article, 'DBIx::SearchBuilder::Record') , "It's a searchbuilder record!");


($id, $msg) = $article->Create( Class => 'ArticleTest', Summary => "ArticleTest");
ok ($id, $msg);
$article->Load($id);
is ($article->Summary, 'ArticleTest', "The summary is set correct");
my $at = RT::FM::Article->new($RT::SystemUser);
$at->Load($id);
is ($at->id , $id);
is ($at->Summary, $article->Summary);




my  $a1 = RT::FM::Article->new($RT::SystemUser);
 ($id, $msg)  = $a1->Create(Class => 1, Name => 'ValidateNameTest');
ok ($id, $msg);



my  $a2 = RT::FM::Article->new($RT::SystemUser);
($id, $msg)  = $a2->Create(Class => 1, Name => 'ValidateNameTest');
ok (!$id, $msg);

my  $a3 = RT::FM::Article->new($RT::SystemUser);
($id, $msg)  = $a3->Create(Class => 1, Name => 'ValidateNameTest2');
ok ($id, $msg);
($id, $msg) =$a3->SetName('ValidateNameTest');

ok (!$id, $msg);

($id, $msg) =$a3->SetName('ValidateNametest2');

ok ($id, $msg);





my $newart = RT::FM::Article->new($RT::SystemUser);
$newart->Create(Name => 'DeleteTest', Class => '1');
$id = $newart->Id;

ok($id, "New article has an id");


 $article = RT::FM::Article->new($RT::SystemUser);
$article->Load($id);
ok ($article->Id, "Found the article");
my $val;
 ($val, $msg) = $article->Delete();
ok ($val, "Article Deleted: $msg");

 $a2 = RT::FM::Article->new($RT::SystemUser);
$a2->Load($id);
ok (!$a2->Id, "Did not find the article");


$RT::Handle->SimpleQuery("DELETE FROM Links");

my $article_a = RT::FM::Article->new($RT::SystemUser);
($id, $msg) = $article_a->Create( Class => 'ArticleTest', Summary => "ArticleTestlink1");
ok($id,$msg);

my $article_b = RT::FM::Article->new($RT::SystemUser);
($id, $msg) = $article_b->Create( Class => 'ArticleTest', Summary => "ArticleTestlink2");
ok($id,$msg);

# Create a link between two articles
($id, $msg) = $article_a->AddLink( Type => 'RefersTo', Target => $article_b->URI);
ok($id,$msg);

# Make sure that Article B's "ReferredToBy" links object refers to to this article"
my $refers_to_b = $article_b->ReferredToBy;
ok($refers_to_b->Count == 1, "Found one thing referring to b");
my $first = $refers_to_b->First;
ok ($first->isa(RT::Link), "IT's an RT link - ref ".ref($first) );
ok ($first->TargetObj->Id == $article_b->Id, "Its target is B");

ok($refers_to_b->First->BaseObj->isa('RT::FM::Article'), "Yep. its an article");


# Make sure that Article A's "RefersTo" links object refers to this article"
my $referred_To_by_a = $article_a->RefersTo;
ok($referred_To_by_a->Count == 1, "Found one thing referring to b ".$referred_To_by_a->Count. "-".$referred_To_by_a->First->id . " - ".$referred_To_by_a->Last->id);
 $first = $referred_To_by_a->First;
ok ($first->isa(RT::Link), "IT's an RT link - ref ".ref($first) );
ok ($first->TargetObj->Id == $article_b->Id, "Its target is B - " . $first->TargetObj->Id);
ok ($first->BaseObj->Id == $article_a->Id, "Its base is A");

ok($referred_To_by_a->First->BaseObj->isa('RT::FM::Article'), "Yep. its an article");

# Delete the link
($id, $msg) = $article_a->DeleteLink(Type => 'RefersTo', Target => $article_b->URI);
ok($id,$msg);


# Create an Article A RefersTo Ticket 1 from the RTFM side
use RT::Ticket;


my $tick = RT::Ticket->new($RT::SystemUser);
$tick->Create(Subject => "Article link test ", Queue => 'General');
$tick->Load($tick->Id);
ok ($tick->Id, "Found ticket ".$tick->id);
($id, $msg) = $article_a->AddLink(Type => 'RefersTo', Target => $tick->URI);
ok($id,$msg);

# Find all tickets whhich refer to Article A

use RT::Tickets;
use RT::Links;

my $tix = RT::Tickets->new($RT::SystemUser);
ok ($tix, "Got an RT::Tickets object");
ok ($tix->LimitReferredToBy($article_a->URI)); 
ok ($tix->Count == 1, "Found one ticket linked to that article");
ok ($tix->First->Id == $tick->id, "It's even the right one");



# Find all articles which refer to Ticket 1
use RT::FM::ArticleCollection;

my $articles = RT::FM::ArticleCollection->new($RT::SystemUser);
ok($articles->isa('RT::FM::ArticleCollection'), "Created an article collection");
ok($articles->isa('RT::FM::SearchBuilder'), "Created an article collection");
ok($articles->isa('RT::SearchBuilder'), "Created an article collection");
ok($articles->isa('DBIx::SearchBuilder'), "Created an article collection");
ok($tick->URI, "The ticket does still have a URI");
$articles->LimitRefersTo($tick->URI);

is($articles->Count(), 1);
is ($articles->First->Id, $article_a->Id);
is ($articles->First->URI, $article_a->URI);



# Find all things which refer to ticket 1 using the RT API.

my $tix2 = RT::Links->new($RT::SystemUser);
ok ($tix2->isa('RT::Links'));
ok($tix2->LimitRefersTo($tick->URI));
ok ($tix2->Count == 1);
is ($tix2->First->BaseObj->URI ,$article_a->URI);



# Delete the link from the RT side.
my $t2 = RT::Ticket->new($RT::SystemUser);
$t2->Load($tick->Id);
($id, $msg)= $t2->DeleteLink( Base => $article_a->URI, Type => 'RefersTo');
ok ($id, $msg . " - $id - $msg");

# it is actually deleted
my $tix3 = RT::Links->new($RT::SystemUser);
$tix3->LimitReferredToBy($tick->URI);
ok ($tix3->Count == 0);

# Recreate the link from teh RT site
($id, $msg) = $t2->AddLink( Base => $article_a->URI, Type => 'RefersTo');
ok ($id, $msg);

# Find all tickets whhich refer to Article A

# Find all articles which refer to Ticket 1




my $art = RT::FM::Article->new($RT::SystemUser);
($id, $msg) = $art->Create (Class => 'ArticleTest');
ok ($id,$msg);

ok($art->URI);
ok($art->__Value('URI') eq $art->URI, "The uri in the db is set correctly");




 $art = RT::FM::Article->new($RT::SystemUser);
($id, $msg) = $art->Create (Class => 'ArticleTest');
ok ($id,$msg);

ok($art->URIObj);
ok($art->__Value('URI') eq $art->URIObj->URI, "The uri in the db is set correctly");



$art = RT::FM::Article->new($RT::SystemUser);
$art->Load(1);
ok ($art->Id == 1, "Loaded article 1");
my $s =$art->Summary;
($val, $msg) = $art->SetSummary("testFoo");
ok ($val, $msg);
ok ($art->Summary eq 'testFoo', "The Summary was set to foo");
my $t = $art->Transactions();
my $trans = $t->Last;
ok ($trans->Type eq 'Core', "It's a core transaction");
ok ($trans->Field eq 'Summary', "it is about setting the Summary");
ok ($trans->NewContent eq 'testFoo', "The new content is 'foo'");
ok ($trans->OldContent, "There was some old value");

