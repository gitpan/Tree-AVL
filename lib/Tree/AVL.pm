package Tree::AVL;

use 5.008007;
use strict;
use warnings;


our $VERSION = '0.02';


#
# AVL.pm
#
# An implementation of an AVL tree for storing comparable objects.  
#
# AVL Trees are balanced binary trees, first introduced
# in "An Algorithm for the Organization of Data" by 
# Adelson-Velskii and Landis in 1962.
#
# Balance is kept in an AVL tree during insertion and
# deletion by maintaining a 'balance' factor in each node.
#
# If the subtree below any node in the tree is evenly balanced,
# the balance factor for that node will be 0.    
#
# When the right-subtree below a node is taller than the left-subtree,
# the balance factor will be 1.  For the opposite case, the balance
# factor will be -1.
#
# If the either subtree is heavier (taller by more than 2 levels) than the 
# other, the balance factor within the node will be set to (+-)2, 
# and the subtree below that node will be rebalanced.  
#
# Re-balancing is done via 'single' or 'double' rotations, each of which
# takes constant-time.
#
# Insertion into an AVL tree will require at most 1 rotation.
#
# Deletion from an AVL tree may take as much as log(n) rotations
# in order to restore balance.
#
# Balanced trees can save huge amounts of time in your programs
# when used over regular flat data structures.  For example, if 
# you are processing as much as 1,125,899,906,842,624 ordered objects 
# on some super-awesome mega workstation, the worst-case time (comparisons)
# required  to access one of those objects will be 1,125,899,906,842,624 if
# you keep them in a flat data structure.    However, using a balanced 
# tree such as a 2-3 tree, a Red-Black tree or an AVL tree, worst-case 
# time (comparisons) required will be just 50.  
# 


package Tree::AVL;
use strict;
use warnings;
use Carp;

##################################################
#
#  AVL tree constructor 
#
##################################################
sub new {
    my $invocant = shift;
    my $class   = ref($invocant) || $invocant;
    my $self = {
	_node => {
	    _obj             => undef,   # Object to store in AVL tree
	    _left_node       => undef,   
	    _right_node      => undef,   
	    _height          => 0,	
	    _balance         => 0,     # (abs(balance) < 2) <-> AVL property
	},

	fcompare         => undef,   # comparison function
	fget_key         => undef,   # function to get key from obj
	fget_data        => undef,  # function to get data from obj
	
	acc_lookup_hash  => undef,
        @_,    # Override previous attributes
    };

    $self = bless $self, $class;

    if(!$self->{fcompare}){
	$self->{fcompare}  = \&default_cmp_func;
    }
    if(!$self->{fget_key}){
	$self->{fget_key}  = sub{ return $_[0]; };
    }
    if(!$self->{fget_data}){
	$self->{fget_data}  = sub{ return $_[0]; };
    }


    return $self;
}


#
# insert
#
# usage:   $tree->insert($object);
#
sub insert
{
    my ($self, $object) = @_;    
    if(!$object){
	croak "Error: inserted uninitialized object into AVL tree.\n";
    }
    $self->avl_insert($object);
    return;
}


#
# avl_insert
#
# usage:  $tree_object->avl_insert($object);
#
sub avl_insert
{
    my ($self, $object, $node, $depth) = @_;

    if(!$depth){
	$depth = 0;	
    }
    if(!$node){
	$node = \$self->{_node};	
    }
        
    my $get_key_func = $self->{fget_key};
    my $key = $get_key_func->($object);
    
    my $node_obj = $$node->{_obj};
    my $own_key;
    
    my $increase = 0;  
    my $change = 0;

    if( !$self->{_node}->{_obj} ) # no root data yet, so populate with $object
    {	    
	$self->{_node}->{_obj} = $object;	
	return;
    }
    else # need to insert object if object is not already in tree
    {	    	    
	$own_key = $node_obj->$get_key_func;

	my $cmpfunc = $self->{fcompare};
	my $result = $cmpfunc->($node_obj, $object);
	
	if($result == 0){ #element is already in tree, do nothing.
	    return 0;
	}	   
	elsif($result < 0){ # insert into right subtree
	    if (!defined($$node->{_right_node})){ # Need to create a new node.

		my $new_node = {
			_obj      => $object,
			_balance  => 0,
			_right_node => undef,
			_left_node => undef,
		};
		  		
		$$node->{_right_node} = $new_node;		
		$increase = 1;	


	    }
	    else{ # descend and insert into right subtree
		$change = $self->avl_insert($object, \$$node->{_right_node}, $depth+1);		       
		$increase = 1 * $change;
	    }
	    
	}  
	else{  # insert into left subtree
	    if (!defined($$node->{_left_node})){  # Need to create a new node.	    		
		
		my $new_node = {
		    _obj      => $object,
		    _balance  => 0,
		    _right_node => undef,
		    _left_node => undef,
		};
		
		$$node->{_left_node} = $new_node;		
		$increase = -1;
	    }
	    else{ # descend and insert into left subtree
		$change = $self->avl_insert($object, \$$node->{_left_node}, $depth+1);
		$increase = -1 * $change;
	    }	    
	}      	
    } # end else determine whether need to insert into left or right subtree 

    $$node->{_balance} = $$node->{_balance} + $increase;

    if($increase && $$node->{_balance}){ 
	my $height_change = $self->rebalance($node);
	$change = 1 - $height_change;
    }
    else{
	$change = 0;
    }

    if($depth == 0){
	$self->{_node} = $$node;
    }

    return $change;
}


#
# remove
#
# usage:  my $found_obj = $avltree->remove($object);
#
# remove an object from tree.   
#
#
sub remove
{
    my ($self, $object) = @_;
    my ($obj) = $self->delete($object);    
    return $obj;
}



#
# avl_delete
#
# usage:  ($found_obj) = $tree->delete($object);
#
# 
sub delete{
    
    my ($self, $object, $node, $depth) = @_;
    
    if(!$node){
	$node = \$self->{_node};	
    }   
    if(!$depth){
	$depth = 0;
    }
    
    my $deleted_node;
    my $change = 0;
    my $decrease = 0;

    if(!$$node->{_obj}){ # no root data yet
  	return;
    }
    else{
	my $node_obj = $$node->{_obj};
	my $get_key_func = $self->{fget_key};
	my $own_key = $get_key_func->($node_obj);
	my $cmpfunc = $self->{fcompare};
	
	my $result = $cmpfunc->($node_obj, $object);
	if($result > 0){  # look into left subtree	
	    if (!defined($$node->{_left_node})){	
		return;
	    }
	    else{
		($deleted_node, my $new_ref, $change) = $self->delete($object, \$$node->{_left_node}, $depth+1);
		if($deleted_node){
		    $$node->{_left_node} = $new_ref;
		    $decrease = -1 * $change;
		}
		else{		    
		    return;
		}
	    }						
	}
	elsif($result < 0){ # look into right subtree
	    if (!defined($$node->{_right_node})){
		return;
	    }
	    else{	
		($deleted_node, my $new_ref, $change) = $self->delete($object, \$$node->{_right_node}, $depth+1);
		if($deleted_node){
		    $$node->{_right_node} = $new_ref;		
		    $decrease = 1 * $change;
		}
		else{
		    return;
		}
	    }	    	
	}  	    
	elsif($result == 0){ # this the node we want to delete FOUND THE NODE.
	    $deleted_node = $$node->{_obj};

	    if(!$$node->{_left_node} && !$$node->{_right_node}){  # this is the node to delete, and it is a leaf node.	
	
		if($depth == 0){ # this is also the root node.
		    
		    $$node = {
			_obj      => undef,
			_balance  => 0,
			_right_node => undef,
			_left_node => undef,
		    };
		    
		}
		else{
		    # this is the node to delete.  It is not the root node and it has no children (it is a leaf)
		    $$node = undef;
		    
		    $change = 1;		   
		    return ($deleted_node, $$node, $change);
		}
	    }
	    elsif(!$$node->{_left_node}){
		$$node = $$node->{_right_node};		
		$change = 1;
	
		return ($deleted_node, $$node, $change);
	    }
	    elsif(!$$node->{_right_node}){
		$$node = $$node->{_left_node};	
		$change = 1;	

		return ($deleted_node, $$node, $change);		
	    }
	    elsif($$node->{_right_node} && $$node->{_left_node}){
		    (my $new_root_obj, $$node->{_right_node}, $change) = $self->delete_smallest(\$$node->{_right_node});	
		    if($self->is_empty($$node->{_right_node})){		   
			delete $$node->{_right_node};
		    }
		    $$node->{_obj} = $new_root_obj;
	    }
	    
	    
	    $decrease = $change;
	
	    
	}  # end else determine whether need to look into left or right subtree, or neither   
    } # end else() there was root data.

    $$node->{_balance} = $$node->{_balance} - $decrease;
    if($decrease){
	if($$node->{_balance}){
	    $change = $self->rebalance($node);
	}
	else{
	    $change = 1;
	}
    }
    else{
	$change = 0;
    }

    return ($deleted_node, $$node, $change);
}






#
# delete_smallest
#
# usage:  $tree_object->delete_smallest();
#
sub delete_smallest
{
    my ($self,
	$node,
	$depth) = @_;        

    if(!$node){
	$node = \$self->{_node};	
    }   

    my $node_obj = $$node->{_obj};
    my $get_key_func = $self->{fget_key};
    my $own_key = $get_key_func->($node_obj);    
    my $decrease = 0;
    my $change = 0;

    if(!$$node->{_left_node}){	
	my $obj = $$node->{_obj};
	if(!$$node->{_right_node} && !$depth){	    
	    $$node = {
		_obj      => undef,
		_balance  => 0,
		_right_node => undef,
		_left_node => undef,
	    };
	    $change = 1;
	}
	else{
	    if($$node->{_right_node}){
		$$node = $$node->{_right_node};		
	    }
	    else{
		$$node = undef;		
	    }
	    if($$node){
		$$node->{_balance} = 0;
	    }	    
	    $change = 1;
	}
	return ($obj, $$node, $change);
    }
    else{
	my ($obj, $newleft, $change) = $self->delete_smallest(\$$node->{_left_node}, 1);	
	$decrease = -1 * $change;	
	$$node->{_left_node} = $newleft;
	$$node->{_balance} = $$node->{_balance} - $decrease;	
	if($decrease){
	    if($$node->{_balance}){
		$change = $self->rebalance($node);
	    }
	    else{
		$change = 1;
	    }
	}	
	return ($obj, $$node, $change);
    }
}


#
# delete_largest
#
# usage:  $tree_object->delete_largest();
#
sub delete_largest
{
    my ($self,
	$node,
	$depth) = @_;        

    if(!$node){
	$node = \$self->{_node};	
    }   

    my $node_obj = $$node->{_obj};
    my $get_key_func = $self->{fget_key};
    my $own_key = $get_key_func->($node_obj);    
    my $decrease = 0;
    my $change = 0;

    if(!$$node->{_right_node}){	
	my $obj = $$node->{_obj};
	if(!$$node->{_left_node} && !$depth){	    
	    $$node = {
		_obj      => undef,
		_balance  => 0,
		_right_node => undef,
		_left_node => undef,
	    };
	    $change = 1;
	}
	else{
	    if($$node->{_left_node}){
		$$node = $$node->{_left_node};		
	    }
	    else{
		$$node = undef;		
	    }
	    if($$node){
		$$node->{_balance} = 0;
	    }	    
	    $change = 1;
	}
	return ($obj, $$node, $change);
    }
    else{
	my ($obj, $newright, $change) = $self->delete_largest(\$$node->{_right_node}, 1);	
	$decrease = 1 * $change;	
	$$node->{_right_node} = $newright;
	$$node->{_balance} = $$node->{_balance} - $decrease;	
	if($decrease){
	    if($$node->{_balance}){
		$change = $self->rebalance($node);
	    }
	    else{
		$change = 1;
	    }
	}	
	return ($obj, $$node, $change);
    }
}




#
# rebalance
#
# Determines what sort of, if any, imbalance exists in the subtree
# rooted at $node, and calls the correct rotation subroutine.
#
sub rebalance
{
    my ($self, $node) = @_;
    my $height_change = 0;

    if($$node->{_balance} < -1){  # left heavy
	if($$node->{_left_node}){
	    if($$node->{_left_node}->{_balance} == 1){ # right heavy
		$height_change = $self->double_rotate_right($node);
	    }
	    else{
		$height_change = $self->rotate_right($node);
	    }
	}
    }
    elsif($$node->{_balance} > 1){ # right heavy
	if($$node->{_right_node}){	   
	    if($$node->{_right_node}->{_balance} == -1){ # left heavy
		$height_change = $self->double_rotate_left($node);
	    }
	    else{
		$height_change = $self->rotate_left($node);		
	    }
	}	
    }
    return $height_change;
}



#
# rotate_right
#
# A single right-rotation.  Yes, this is *very* similar code for right and left operations,
# but these subroutines have not been merged to one in the interest of clarity.  After all, according to 
# Abelson and Sussman, programs are for humans to read above all, and only incidentally for machines
# to run.   Not that this code is as readable as it could be, of course.
#
sub rotate_right
{
    my ($self, $node) = @_;
    my $height_change = 0;
    my $lr_grandchild;
    my $lnode;

    if($$node->{_left_node}){
	$lnode = $$node->{_left_node};
    }
	
    # determine height_change
    if($$node->{_right_node} && $$node->{_left_node}){
	$height_change = $$node->{_left_node}->{_balance} == 0 ? 0 : 1;	
    }
    else{
	$height_change = 1;	
    }
    
    # do the rotation
    if(defined($$node->{_left_node})){	
	if($$node->{_left_node}->{_right_node}){           
	    $lr_grandchild = $$node->{_left_node}->{_right_node}; # becomes left child's new right child
	}
    }
    $$node->{_left_node} = $lr_grandchild;   
    if($lnode){
	$lnode->{_right_node} = $$node;	    
	$$node =  $lnode;
    }

    # update balances
    if($$node->{_right_node}){
	$$node->{_right_node}->{_balance} = $$node->{_right_node}->{_balance} + (1 - min($$node->{_balance}, 0));	
	$$node->{_balance} = $$node->{_balance} + (1 + max($$node->{_right_node}->{_balance}, 0));   
    }

    return $height_change;    
}

#
# rotate_left
#
# A single left-rotation.  Yes, this is *very* similar code for right and left operations,
# but these subroutines have not been merged to one in the interest of clarity.  After all, according to 
# Abelson and Sussman, programs are for humans to read above all, and only incidentally for machines
# to run.  Not that this code is as readable as it could be, of course.
#
sub rotate_left
{
    my ($self, $node) = @_;
    my $height_change = 0;
    my $rl_grandchild;
    my $rnode;
    
    if($$node->{_right_node}){
	$rnode = $$node->{_right_node};
    }

    # determine height_change
    if($$node->{_left_node} && $$node->{_right_node}){	
	$height_change = $$node->{_right_node}->{_balance} == 0 ? 0 : 1;	
    }
    else{
	$height_change = 1;	
    }

    if(defined($$node->{_right_node})){	
	if($$node->{_right_node}->{_left_node}){           
	    $rl_grandchild = $$node->{_right_node}->{_left_node}; # becomes left child's new right child
	}
    }
    $$node->{_right_node} = $rl_grandchild;

    if($rnode){
	$rnode->{_left_node} = $$node;	    
	$$node =  $rnode;
    }

     # update balances
    if($$node->{_left_node}){
	$$node->{_left_node}->{_balance} = $$node->{_left_node}->{_balance} - (1 + max($$node->{_balance}, 0));	
	$$node->{_balance} = $$node->{_balance} - (1 - min($$node->{_left_node}->{_balance}, 0));
    }



    return $height_change;   
}


#
# double_rotate_right
#
# A double right-rotation.  Yes, this is *very* similar code for right and left operations,
# but these subroutines have not been merged to one in the interest of clarity.  After all, according to 
# Abelson and Sussman, programs are for humans to read above all, and only incidentally for machines
# to run.  Not that this code is as readable as it could be, of course.
#
sub double_rotate_right
{
    my ($self, $node) = @_;
    
    my $old_balance = $$node->{_balance};
    my $old_l_balance = 0;
    my $old_r_balance = 0;
    
    if($$node->{_left_node}){
	$old_l_balance = $$node->{_left_node}->{_balance};
    }
    if($$node->{_right_node}){
	$old_r_balance = $$node->{_right_node}->{_balance};
    }

    if($$node->{_left_node}){
	$self->rotate_left(\$$node->{_left_node});	
    }

    $self->rotate_right($node);
    
    if($$node->{_left_node}){
	$$node->{_left_node}->{_balance} = -1 * max($old_r_balance, 0);
    }
    if($$node->{_right_node}){
	$$node->{_right_node}->{_balance} = -1 * min($old_r_balance, 0);
    }
    $$node->{_balance} = 0;
    
   
    return 1;
}


#
# double_rotate_left
#
# A double left-rotation.  Yes, this is *very* similar code for right and left operations,
# but these subroutines have not been merged to one in the interest of clarity.  After all, according to 
# Abelson and Sussman, programs are for humans to read above all, and only incidentally for machines
# to run.    Not that this code is as readable as it could be, of course.
#
sub double_rotate_left
{
   my ($self, $node) = @_;
   my $old_balance = $$node->{_balance};
   my $old_l_balance = 0;
   my $old_r_balance = 0;
      
   if($$node->{_left_node}){
       $old_l_balance = $$node->{_left_node}->{_balance};
   }
   if($$node->{_right_node}){
       $old_r_balance = $$node->{_right_node}->{_balance};
   }
   
   if($$node->{_right_node}){
       $self->rotate_right(\$$node->{_right_node});       
   }
   $self->rotate_left($node);
   
   if($$node->{_left_node}){
       $$node->{_left_node}->{_balance} = -1 * max($old_l_balance, 0);
   }
   if($$node->{_right_node}){
       $$node->{_right_node}->{_balance} = -1 * min($old_l_balance, 0);
   }
   $$node->{_balance} = 0;
   
   return 1;
}




sub is_empty{
    my ($self, $node) = @_;
    
    if(!$node){
	$node = $self->{_node};
    }
    
    if(!$node->{_obj}){
	return 1;
    }
    return 0;
}



sub largest
{
    my ($self, $node) = @_;
    
    if(!$node){
	$node = $self->{_node};
    }     
    my $obj = $node->{_obj};
    my $rnode = $node->{_right_node};
    if(!$rnode){
	return $obj;
    }
    else{
	my $obj = $self->largest($rnode);
	return $obj;
    }   
}


sub smallest
{
    my ($self, $node) = @_;
    
    if(!$node){
	$node = $self->{_node};
    }
    my $obj = $node->{_obj};
    my $lnode = $node->{_left_node};
    if(!$lnode){
	return $obj;
    }
    else{
	my $obj = $self->smallest($lnode);
	return $obj;
    }   
}


sub pop_largest
{
    my ($self) = @_;    
    my ($obj) = $self->delete_largest();	   
    return $obj;
}


sub pop_smallest
{
    my ($self) = @_;
    my ($obj) = $self->delete_smallest(); 
    return $obj;
}



sub get_key
{
    my ($self, $node) = @_;
    my $get_key_func = $self->{fget_key};
    my $obj = $node->{_obj};
    my $key = $get_key_func->($obj);   
    return $key;
}


sub get_data
{
    my ($self, $node) = @_;
    my $get_data_func = $self->{fget_data};
    my $obj = $node->{_obj};    
    my $data = $get_data_func->($obj);   
    return $data;    
}



sub get_height
{    
    my ($self, $node) = @_;
       
    my $depth_left = 0;
    my $depth_right = 0;

    if(!$node){
	$node = $self->{_node};	
    }

    if(!$node->{_left_node} && !$node->{_right_node}){
	return 0;
    }
    else
    {
	if($node->{_left_node}){
	    $depth_left = 1 + $self->get_height($node->{_left_node});
	}
	if($node->{_right_node}){	 
	    $depth_right = 1 + $self->get_height($node->{_right_node});
	}

	return $depth_left < $depth_right ? $depth_right : $depth_left;
    }
}



#
# lookup
#
# usage:  $data = $tree_ref->lookup($object)
#
sub lookup
{
    my ($self,
	$object,
	$cmpfunc) = @_;

    my $node = $self->{_node};

    if(!$node->{_obj}){ # no root data yet
	return;
    }
    else{
	
	while($node){
	    my $node_obj = $node->{_obj};
	    my $get_key_func = $self->{fget_key};
	    my $key = $get_key_func->($node_obj);

	    if(!$cmpfunc){
		$cmpfunc = $self->{fcompare};
	    }
	    my $result = $cmpfunc->($node_obj, $object);
	    if($result == 0){ # element is already in tree- return the key.
		return $key;
	    }	   
	    elsif($result < 0){ # look into right subtree
		$node = $node->{_right_node};
	    }  
	    else{  # look into left subtree
		$node = $node->{_left_node};		
	    } 		    
	} # end while
	return;
    } # end else 
}





#
# lookup_obj
#
# usage:  $object = $tree_ref->lookup($object)
#
sub lookup_obj
{
    my ($self,
	$object,
	$cmpfunc) = @_;

    my $node = $self->{_node};

    if( !$node->{_obj} ) # no root data yet
    {	    
	return;
    }
    else 
    {
	while($node){
	    my $node_obj = $node->{_obj};
	    
	    if(!$cmpfunc){
		$cmpfunc = $self->{fcompare};
	    }
	    my $result = $cmpfunc->($node_obj, $object);
	    if($result == 0){ # element is already in tree- return the key.
		return $node_obj;
	    }	   
	    elsif($result < 0){ # look into right subtree
		$node = $node->{_right_node};
	    }  
	    else{  # look into left subtree
		$node = $node->{_left_node};		
	    } 		    
	} # end while
	return;
    } # end else 
}





#
# acc_lookup
#
# usage:    $tree_ref->lookup($object)
#
# accumulative lookup, returns a list of all
# items whose keys satisfy the match function for the key for $object.
#
# For example, if used with a relaxed compare function such as:
#
# $word->compare_up_to($arg_word);
# 
# which returns true if the argument word is a proper 'superstring' of $word
# (meaning that it contains $word followed by one or more characters)
# this will return a list of all the words that are superstrings of
# $word.
#
sub acc_lookup
{
    
    my ($self,
	$object,
	$partial_cmpfunc, # partial comparison function to use
	$exact_cmpfunc, # exact comparison function to use
	$node,
	$acc_results) = @_;
    
    if(!$node){
	$node = $self->{_node};
    }
    
    # the list of accumulated results
    if(!$acc_results){
	$acc_results = ();
    }
        
    if(!$partial_cmpfunc || !$exact_cmpfunc){
	return ();
    }
    
    if(!$node->{_obj}){ # no root data yet    	    
	return ();
    }
    else 
    {	 
	while($node){
	    my $node_obj = $node->{_obj};
	    my $get_key_func = $self->{fget_key};
	    my $node_key = $get_key_func->($node_obj);
	    my $partial_cmp = $partial_cmpfunc->($node_obj, $object);
	    my $exact_cmp = $exact_cmpfunc->($node_obj, $object);

	    if($partial_cmp == 0){ # found a match on partial cmp
		
		if(!$acc_results){
		    @$acc_results = ();
		}
		push(@$acc_results, $node_key);
		
		if($exact_cmp == 0){ # any other partial matches will be in right subtree		    
		    $node = $node->{_right_node};					    
		}
		else{

		    if ($node->{_right_node} && $node->{_left_node}){
			my $rightnode = $node->{_right_node};
			my $leftnode = $node->{_left_node};
		
			return @$acc_results = ($self->acc_lookup($object, $partial_cmpfunc, 
								  # do not pass in acc_results here
								  $exact_cmpfunc, $rightnode), 
						$self->acc_lookup($object, $partial_cmpfunc, 
								  $exact_cmpfunc, $leftnode, \@$acc_results));
		    }
		    elsif($node->{_right_node}){
		        my $rightnode = $node->{_right_node};
			@$acc_results = ($self->acc_lookup($object, $partial_cmpfunc, 
								$exact_cmpfunc, $rightnode, \@$acc_results));	
		    }
		    elsif($node->{_left_node}){
			my $leftnode = $node->{_left_node};
			@$acc_results = ($self->acc_lookup($object, $partial_cmpfunc, 
							       $exact_cmpfunc, $leftnode, \@$acc_results));
		    }
		    return @$acc_results;
		}
	    }	   
	    elsif($partial_cmp < 0){ # look into right subtree	
		$node = $node->{_right_node};		    
	    }  
	    else{  # look into left subtree
		$node = $node->{_left_node};	
	    }	    
	} # end while
	if(defined(@$acc_results)){
	    return @$acc_results;
	}
	return;
    }  # end else determine whether need to look into left or right subtree 	    
}




#
# acc_lookup_memo
#
# memoized call to acc_lookup
#
sub acc_lookup_memo
{
    my ($self,
	$object,
   	$partial_cmpfunc,  # partial comparison function to use
	$exact_cmpfunc   # exact comparison function to use
	) = @_;
   
    my $get_key_func = $self->{fget_key};
    
    my $obj_key = $get_key_func->($object);	
    my $acc_lookup_hash_key = $obj_key . $partial_cmpfunc . $exact_cmpfunc;
    
    
    if($self->{acc_lookup_hash}->{$acc_lookup_hash_key}){
	my $list = $self->{acc_lookup_hash}->{$acc_lookup_hash_key};
	return @$list;
	}
    else{
	my @results = $self->acc_lookup($object, $partial_cmpfunc, $exact_cmpfunc);
	$self->{acc_lookup_hash}->{$acc_lookup_hash_key} = \@results;
	return @results;
    }    
}





#
# get_list_recursive
#
# usage:    @list_array = $tree_ref->get_list_recursive()
#
# returns an array (list) containing all elements in the tree (in-order).
#
sub get_list_recursive
{
    my ($self, $node, $lst) = @_; 
    	
    if(!$node){
	$node = $self->{_node};
    }    
    if(!$lst){
	$lst = [];
    }          
    if($node->{_left_node}){
	@$lst = $self->get_list($node->{_left_node}, $lst);
    }
    my $obj = $node->{_obj};
    if($obj){	
	push(@$lst, $obj);
    }    
    if($node->{_right_node}){
	$self->get_list($node->{_right_node}, $lst);
    }    
    return @$lst;
}



#
# get_list
#
# usage:    @list_array = $tree_ref->get_list()
#
# returns an array (list) containing all elements in the tree (in-order).
#
sub get_list
{
    my ($self) = @_;

    my $node = $self->{_node};

    my @stack;
    my $i = 0;

    my @objs;

    while(1){
	while($node){	    
	    $stack[$i] = $node; 	     
	    $i++;
	    $node = $node->{_left_node};	    
	}
	if($i == 0){
	    last;
	}
	--$i;
	push(@objs, $stack[$i]->{_obj});
	$node = $stack[$i];	

	$node = $node->{_right_node};
    }

    return @objs;
}

#
# get_size
#
# returns number of objects in the tree
#
#
sub get_size
{
    my ($self) = @_;         
    my @list = $self->get_list();
    my $size = @list;
    
    return $size;
}




#
# iterator
#
# usage:    my $it = $tree_ref->iterator(">") # high-to-low
#           my $it = $tree_ref->iterator("<") # low-to-high
#
# returns an iterator over elements in the tree (in order specified).
#
sub iterator
{
    my ($self, $order) = @_;
    
    my $first_dir;
    my $second_dir;
    
    if(!$order){ $order = "<"; }

    if($order eq ">"){ # high to low
	$first_dir = "_right_node";
	$second_dir = "_left_node";
    }
    else{ # low to high (default)
	$first_dir = "_left_node";
	$second_dir = "_right_node";	
    }

    my @stack;
    my $i = 0;
    my $node = $self->{_node};
    
    return sub{	  
	while(1){
	    while($node){	    
		$stack[$i] = $node; 	     
		$i++;
		$node = $node->{$first_dir};	    
	    }		
	    if($i == 0){
		last;
	    }		
	    --$i;		
	    my $obj = $stack[$i]->{_obj};
	    $node = $stack[$i];			
	    $node = $node->{$second_dir};
	    return $obj;	    
	}	    	
	return;
    }
}


sub get_keys_recursive
{
    my ($self, $node) = @_;
    my @keys;

    if(!$node){
	$node = $self->{_node};
    }
 
    if($node->{_left_node}){
	push(@keys, $self->get_keys($node->{_left_node}));
    }
    
    push(@keys, $self->get_key($node));
    
    if($node->{_right_node}){	
	push(@keys, $self->get_keys($node->{_right_node}));
    }
    return @keys;
}



sub get_keys
{
    my ($self) = @_;
    my $node = $self->{_node};
    my @stack;
    my $i = 0;
    my @keys;

    while(1){
	while($node){	    
	    $stack[$i] = $node; 	     
	    $i++;
	    $node = $node->{_left_node};	    
	}
	if($i == 0){
	    last;
	}
	--$i;
	push(@keys, $self->get_key($stack[$i]));
	$node = $stack[$i];	

	$node = $node->{_right_node};
    }
    return @keys;
}





sub get_keys_iterator
{
    my ($self) = @_;
    my @stack;
    my $i = 0;
    my $node = $self->{_node};

    return sub{
	  
	while(1){
	    while($node){	    
		$stack[$i] = $node; 	     
		$i++;
		$node = $node->{_left_node};	    
	    }		
	    if($i == 0){
		last;
	    }		
	    --$i;		
	    my $key = $self->get_key($stack[$i]);
	    $node = $stack[$i];			
	    $node = $node->{_right_node};
	    return $key;	    
	}	    
	
	return;
    }
}




################################################################################
#
#  Printing functions
#
#
################################################################################
sub print
{
    my ($self, $char, $o_char, $node, $depth) = @_;

    if(!$node && !defined($depth)){       
	$node = $self->{_node};
    }
    if(!$depth){ $depth = 0; }
    if(!$o_char){
	$o_char = $char;
    }
           
    print $char . $self->get_key($node) . ": " . $self->get_data($node);
    print ": height: " . $self->get_height($node) . ": balance: " . $node->{_balance} . "\n";

    if($node->{_left_node}){
	my $leftnode = $node->{_left_node};
	$self->print($char . $o_char, $o_char, $leftnode, $depth+1);
    }
    if($node->{_right_node}){
	my $rightnode =  $node->{_right_node};
	$self->print($char . $o_char, $o_char, $rightnode, $depth+1);
    }
}




sub print_node
{
    my ($self, $node, $char, $o_char) = @_;

    if(!$o_char){
	$o_char = $char;
    }           
    print $char . $self->get_key($node) . ": " . $self->get_data($node) .  ": balance: " . $node->{_balance} . "\n";
    if($node->{_left_node}){
	my $leftnode = $node->{_left_node};
	$self->print_node($leftnode, $char . $o_char, $o_char);
    }
    if($node->{_right_node}){
	my $rightnode =  $node->{_right_node};
	$self->print_node($rightnode, $char . $o_char, $o_char);
    }
}

sub print_iterative
{
    my ($self) = @_;
    my @stack;

    my $node = $self->{_node};

    my $i = 0;

    while(1){
	while($node){	    
	    $stack[$i] = $node; 	     
	    $i++;
	    $node = $node->{_left_node};	    
	}

	if($i == 0){
	    last;
	}
	--$i;
	print $self->get_key($stack[$i]) . "\n";
	$node = $stack[$i];	

	$node = $node->{_right_node};
    }
}




#
# default_cmp_func
#
# default comparison function to use in case none is supplied.
# uses lexical comparator.
#
sub default_cmp_func
{
    my ($obj1, $obj2) = @_;

    if($obj1 lt $obj2){
	return -1;
    }
    elsif($obj1 gt $obj2){
	return 1;	
    }
    return 0;
}



sub min
{
    my ($a, $b) = @_;    
    return $a < $b ? $a : $b;
}


sub max
{
    my ($a, $b) = @_;
    return $a < $b ? $b : $a;
}


1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Tree::AVL - Perl implemenation of an AVL tree for storing comparable objects 


=head1 SYNOPSIS


use Tree::AVL;


=head2 EXAMPLE 1

#
#  This example shows usage with default constructor.
#
#  With default constructor, the tree works with strings.
#
#  Constructor can also be passed a comparison function,
#  and accessor methods to use, so that you can store any
#  type of object in the tree (see Example 2).
#
#

# create a tree with default constructor
my $avltree = Tree::AVL->new();

# can insert strings by default
$avltree->insert("arizona");  
$avltree->insert("arkansas");
$avltree->insert("massachusetts");
$avltree->insert("maryland");
$avltree->insert("montana");
$avltree->insert("madagascar");

print $avltree->get_height() . "\n";  # output: 2 (height is zero-based)

$avltree->print("*"); # output:
                      #
                      # *maryland: maryland: height: 2: balance: 0
                      # **massachusetts: massachusetts: height: 1: balance: 0
                      # ***montana: montana: height: 0: balance: 0
                      # **arkansas: arkansas: height: 1: balance: 0
                      # ***madagascar: madagascar: height: 0: balance: 0
                      # ***arizona: arizona: height: 0: balance: 0

my $obj = $avltree->remove("maryland");
print "found: $obj\n";  # output: found: maryland
my $obj = $avltree->remove("maryland");
if(!$obj){
    print "object was not in tree.\n";
}

$avltree->print("*"); # output:
                      # 
                      # *madagascar: madagascar: height: 2: balance: 0
                      # **massachusetts: massachusetts: height: 1: balance: 0
                      # ***montana: montana: height: 0: balance: 0
                      # **arkansas: arkansas: height: 1: balance: 1
                      # ***arizona: arizona: height: 0: balance: 0


# retreive an iterator over the objects in the tree.
my $iterator = $avltree->iterator();
while(my $obj = $iterator->()){
    print $obj . "\n";   # outputs objects in order low-to-high
}

# retreive a reverse-order iterator over the objects in the tree.
my $iterator = $avltree->iterator(">");
while(my $obj = $iterator->()){
    print $obj . "\n"; # outputs objects in order high-to-low
}

# retrieve all objects from tree at once
my @list = $avltree->get_list();
foreach my $obj (@list){
    print $obj . "\n"; # outputs objects in order low-to-high
}


my $obj = $avltree->pop_smallest();  # retrieves arizona
print "$obj\n";

my $obj = $avltree->pop_largest();  # retrieves montana
print "$obj\n";



undef $avltree;


=head2 EXAMPLE 2


#
#  Shows how to instantiate tree and specify key, data and
#  comparison functions.   insert any object
#  you want.   Here a basic hash is used, but 
#  any object of your creation will do when you 
#  supply an appropriate comparison function.
#


my $elt1 = { _name => "Bob",
	     _phone => "444-4444",};

my $elt2 = { _name => "Amy",
	     _phone => "555-5555",};

my $elt3 = { _name => "Sara",
	     _phone => "666-6666",}; 

$avltree = Tree::AVL->new(
    fcompare => sub{ my ($o1, $o2) = @_;
		     if($o1->{_name} gt $o2->{_name}){ return -1}
		     elsif($o1->{_name} lt $o2->{_name}){ return -1}
		     return 0;},
    fget_key => sub{ my($obj) = @_;
		     return $obj->{_name};},
    fget_data => sub{ my($obj) = @_;
		      return $obj->{_phone};},
    );



$avltree->insert($elt1);
$avltree->insert($elt2);
$avltree->insert($elt3);


$avltree->print("-");   # output:
                        #
                        # -Bob: 444-4444: height: 1: balance: 1
                        # --Amy: 555-5555: height: 0: balance: 0
                        #

$avltree->insert($elt4); # output: "Error: inserted uninitialized object.."


exit;
  

=head1 DESCRIPTION

AVL Trees are balanced binary trees, first introduced
in "An Algorithm for the Organization of Data" by 
Adelson-Velskii and Landis in 1962.

Balance is kept in an AVL tree during insertion and
deletion by maintaining a 'balance' factor in each node.

If the subtree below any node in the tree is evenly balanced,
the balance factor for that node will be 0.    

When the right-subtree below a node is taller than the left-subtree,
the balance factor will be 1.  For the opposite case, the balance
factor will be -1.

If the either subtree is heavier (taller by more than 2 levels) than the 
other, the balance factor within the node will be set to (+-)2, 
and the subtree below that node will be rebalanced.  

Re-balancing is done via 'single' or 'double' rotations, each of which
takes constant-time.

Insertion into an AVL tree will require at most 1 rotation.

Deletion from an AVL tree may take as much as log(n) rotations
in order to restore balance.

Balanced trees can save huge amounts of time in your programs
when used over regular flat data structures.  For example, if 
you are processing as much as 1,125,899,906,842,624 ordered objects 
on some super-awesome mega workstation, the worst-case time (comparisons)
required  to access one of those objects will be 1,125,899,906,842,624 if
you keep them in a flat data structure.    However, using a balanced 
tree such as a 2-3 tree, a Red-Black tree or an AVL tree, worst-case 
time (comparisons) required will be just 50.  


=head2 EXPORT

None by default.



=head1 SEE ALSO

"An Algorithm for the Organization of Information",  G.M. Adelson-Velsky and
E.M. Landis.

=head1 AUTHOR

Matthias Beebe, E<lt>matthiasbeebe@gmail.com<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Matthias Beebe

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
