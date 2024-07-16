<script>

    export let name;
    
    export let active;
  </script>
  
  <li class="menu-item" class:active>
    <!-- <a href="" on:click|preventDefault={() => (active = name)}>       -->
      <span>{name}</span>
    <!-- </a> -->
  </li>
  
  <style>
    .menu-item {
      border-bottom: 1px solid #ddd; /* Add a bottom border for separators */
    }
  
    .menu-item:last-child {
      border-bottom: none; /* Remove the bottom border for the last item */
    }
  
   
    .menu-item.active {
      font-weight: bold;
      background-color: #f0f0f0;
    }

  </style>
  