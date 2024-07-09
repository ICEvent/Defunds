<script>

    export let name;
    export let icon; // Add a new prop for the icon
    export let active;
  </script>
  
  <li class="menu-item" class:active>
    <a href="#" on:click|preventDefault={() => (active = name)}>
      
      <span>{name}</span>
    </a>
  </li>
  
  <style>
    .menu-item {
      border-bottom: 1px solid #ddd; /* Add a bottom border for separators */
    }
  
    .menu-item:last-child {
      border-bottom: none; /* Remove the bottom border for the last item */
    }
  
    .menu-item a {
      display: flex;
      align-items: center;
      padding: 10px;
      text-decoration: none;
      color: #333;
    }
  
    .menu-item a:hover {
      background-color: #f5f5f5;
    }
  
    .menu-item.active {
      font-weight: bold;
      background-color: #f0f0f0;
    }
  
    .menu-item .icon {
      margin-right: 10px; /* Add some spacing between the icon and text */
    }
  </style>
  